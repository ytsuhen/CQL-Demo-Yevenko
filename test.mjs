// Scenario run: CQL → ELM compilation, scenario facts → FHIR Observations,
// execution by cql-execution + cql-exec-fhir, comparison with expect (the core lives in engine.mjs).
//
//   node test.mjs           — PASS / FAIL for every scenario
//   node test.mjs --trace   — the same plus the value of every define
//   node test.mjs 01 20     — only scenarios whose file names start with 01 or 20
//
// Exit code 1 on a compilation error or any FAIL, so `npm test` works in CI as is.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DEFAULT_RULE, runScenario } from "./engine.mjs";
import { compile, readSources, writeElm, printErrors } from "./compile.mjs";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const SCENARIO_DIR = path.join(ROOT, "scenarios");

const fmt = v => (v === null ? "null" : JSON.stringify(v));

// ---------- CLI ----------

async function main() {
  const args = process.argv.slice(2);
  const traceAll = args.includes("--trace");
  const filters = args.filter(a => !a.startsWith("--"));

  const sources = readSources();
  const { elm, errors } = compile(sources);
  writeElm(elm);
  console.log(`Compiled: ${Object.keys(elm).length} of ${Object.keys(sources).length} libraries`);
  if (errors.length) {
    printErrors(errors);
    console.log("\nScenarios not run: fix the compilation errors first.");
    return 1;
  }

  const vocabulary = JSON.parse(fs.readFileSync(path.join(ROOT, "vocabulary.json"), "utf8"));
  const files = fs
    .readdirSync(SCENARIO_DIR)
    .filter(f => f.endsWith(".json"))
    .filter(f => filters.length === 0 || filters.some(p => f.startsWith(p)))
    .sort();

  let passed = 0;
  console.log("");
  for (const file of files) {
    let scenario;
    try {
      scenario = JSON.parse(fs.readFileSync(path.join(SCENARIO_DIR, file), "utf8"));
    } catch (e) {
      console.log(`ERROR ${file}  Cannot parse JSON: ${e.message}`);
      continue;
    }
    const rule = scenario.rule ?? DEFAULT_RULE;
    if (!elm[rule]) {
      console.log(`ERROR ${file}  Rule “${rule}” not found: it needs the file cql/${rule}.cql`);
      continue;
    }

    let r;
    try {
      r = await runScenario(elm, rule, scenario, vocabulary);
    } catch (e) {
      const msg = String(e?.message ?? e);
      const line = msg.split("\n").find(l => l.includes("Error Message")) ?? msg.split("\n")[0];
      console.log(`ERROR ${file}  ${line.replace(/^\s*Error Message:\s*/, "")}`);
      continue;
    }

    if (r.pass) passed++;
    console.log(`${r.pass ? "PASS " : "FAIL "} ${file}  [${rule}] ${scenario.name ?? ""}`);
    for (const f of r.failures) console.log(`        ✗ ${f.step}: expected ${fmt(f.expected)}, got ${fmt(f.got)}`);
    if (traceAll || !r.pass) {
      const width = Math.max(...r.trace.map(([step]) => step.length));
      for (const [step, value] of r.trace) {
        const mark = step in (scenario.expect ?? {}) ? (r.failures.some(f => f.step === step) ? "✗" : "✓") : " ";
        console.log(`      ${mark} ${step.padEnd(width)} = ${value}`);
      }
      console.log("");
    }
  }

  console.log(`\n${passed} / ${files.length} PASS`);
  return passed === files.length && files.length > 0 ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await main();
}
