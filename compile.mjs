// CQL → ELM compilation with the cqframework reference translator (@cqframework/cql).
// Reads every cql/*.cql, checks types and references and writes elm/<Library>.json.
//
//   node compile.mjs   — compile only; exit code 1 on errors

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { compile } from "./engine.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
export const CQL_DIR = path.join(ROOT, "cql");
export const ELM_DIR = path.join(ROOT, "elm");

export { compile };

/** Reads every cql/*.cql: { "HeadacheTriage": "<text>", … } */
export function readSources(dir = CQL_DIR) {
  const sources = {};
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith(".cql")).sort()) {
    sources[f.replace(/\.cql$/, "")] = fs.readFileSync(path.join(dir, f), "utf8");
  }
  return sources;
}

/** Writes elm/<Library>.json, removing old files so renamed libraries leave no stale ELM */
export function writeElm(elm, dir = ELM_DIR) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
  for (const [name, json] of Object.entries(elm)) {
    fs.writeFileSync(path.join(dir, `${name}.json`), JSON.stringify(json, null, 2) + "\n");
  }
}

/** Prints errors as file:line:col, the way editors show them */
export function printErrors(errors) {
  for (const e of errors) {
    const where = e.line ? `cql/${e.library}.cql:${e.line}:${e.col}` : `cql/${e.library}.cql`;
    console.log(`  ERROR ${where}  ${e.message}`);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const sources = readSources();
  const { elm, errors } = compile(sources);
  writeElm(elm);
  for (const name of Object.keys(sources)) {
    const ok = elm[name] && !errors.some(e => e.library === name);
    console.log(`${ok ? "  OK   " : "  FAIL "} ${name}.cql${ok ? ` → elm/${name}.json` : ""}`);
  }
  if (errors.length) {
    console.log("");
    printErrors(errors);
    process.exit(1);
  }
}
