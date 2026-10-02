// Builds the web version into dist/: the page plus the engine for the browser.
//
//   dist/engine.js  — engine.mjs with the translator and the engine in one file (window.DemoEngine)
//   dist/index.html — web/index.html with the current cql/*.cql, vocabulary.json and scenarios/*.json embedded
//   dist/receipt.html — web/receipt.html as is: shows a decision receipt carried in the link after "#"
//
// So the web version always shows the same rules and scenarios as `npm test`.

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import * as esbuild from "esbuild";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DIST = path.join(ROOT, "dist");

// Node modules that browsers lack. The engine does not really use them:
// cql-exec-fhir needs fs only to read files from disk, xml2js needs timers only for setImmediate.
const nodeShims = {
  name: "node-shims",
  setup(build) {
    build.onResolve({ filter: /^(fs|timers)$/ }, args => ({ path: args.path, namespace: "shim" }));
    build.onLoad({ filter: /.*/, namespace: "shim" }, args => ({
      contents:
        args.path === "timers"
          ? "module.exports = { setImmediate: (fn, ...a) => setTimeout(fn, 0, ...a), clearImmediate: clearTimeout };"
          : "module.exports = {};",
      loader: "js",
    }));
  },
};

function readDir(dir, ext) {
  const out = {};
  for (const f of fs.readdirSync(path.join(ROOT, dir)).filter(f => f.endsWith(ext)).sort()) {
    out[f] = fs.readFileSync(path.join(ROOT, dir, f), "utf8");
  }
  return out;
}

fs.rmSync(DIST, { recursive: true, force: true });
fs.mkdirSync(DIST, { recursive: true });

await esbuild.build({
  entryPoints: [path.join(ROOT, "engine.mjs")],
  outfile: path.join(DIST, "engine.js"),
  bundle: true,
  format: "iife",
  globalName: "DemoEngine",
  platform: "browser",
  target: "es2020",
  minify: true,
  legalComments: "none",
  define: { "process.env.NODE_ENV": '"production"' },
  plugins: [nodeShims],
  logLevel: "warning",
});

const sources = Object.fromEntries(Object.entries(readDir("cql", ".cql")).map(([f, text]) => [f.replace(/\.cql$/, ""), text]));
const seed = {
  sources,
  vocabulary: fs.readFileSync(path.join(ROOT, "vocabulary.json"), "utf8"),
  scenarios: readDir("scenarios", ".json"),
};
seed.version = crypto.createHash("sha256").update(JSON.stringify(seed)).digest("hex").slice(0, 12);

// Escape "<" so rule text can never close the <script> tag
const seedJson = JSON.stringify(seed).replace(/</g, "\\u003c");
const page = fs.readFileSync(path.join(ROOT, "web", "index.html"), "utf8");
if (!page.includes("/*SEED*/")) throw new Error("web/index.html: no /*SEED*/ placeholder to fill");
fs.writeFileSync(path.join(DIST, "index.html"), page.replace("/*SEED*/", () => seedJson));
fs.writeFileSync(path.join(DIST, ".nojekyll"), "");
// The decision receipt page: a QR code in a presentation opens a receipt here, carried entirely in the link
fs.copyFileSync(path.join(ROOT, "web", "receipt.html"), path.join(DIST, "receipt.html"));

const kb = f => Math.round(fs.statSync(path.join(DIST, f)).size / 1024);
console.log(`dist/index.html  ${kb("index.html")} KB  (${Object.keys(sources).length} libraries, ${Object.keys(seed.scenarios).length} scenarios)`);
console.log(`dist/engine.js   ${kb("engine.js")} KB`);
