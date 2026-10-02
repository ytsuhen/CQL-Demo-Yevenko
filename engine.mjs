// The demo core: CQL → ELM compilation, scenario facts → FHIR, execution and comparison with expect.
// Shared by the terminal commands (compile.mjs, test.mjs) and the web version (web/): nothing here
// is Node-specific, so the same code is bundled into engine.js for the browser.

import {
  CqlTranslator,
  LibraryManager,
  ModelManager,
  createLibrarySourceProvider,
  createModelInfoProvider,
  createUcumService,
  stringAsSource,
} from "@cqframework/cql/cql-to-elm";
import { SystemModelInfoProvider } from "@cqframework/cql/cql";
import cql from "cql-execution";
import cqlfhir from "cql-exec-fhir";
import ucum from "@lhncbc/ucum-lhc";
// The FHIR R4 model: the same modelinfo the engine uses (cql-exec-fhir)
import FHIR_MODELINFO from "cql-exec-fhir/lib/modelInfos/fhir-modelinfo-4.0.1.xml.js";

export const DEFAULT_RULE = "SymptomTriage";

// ---------- compilation ----------

// The translator's UCUM service checks units in literals such as 38.0 'Cel'.
// Without it the translator stops with “No default UCUM service available”.
const units = ucum.UcumLhcUtils.getInstance();
const ucumService = createUcumService(
  (value, from, to) => {
    const r = units.convertUnitTo(from, Number(value), to);
    if (r.status !== "succeeded") throw new Error(`UCUM: ${from} → ${to}: ${r.msg.join("; ")}`);
    return String(r.toVal);
  },
  unit => {
    const r = units.validateUnitString(unit, true);
    return r.status === "valid" ? null : `'${unit}' is not a valid UCUM unit`;
  },
  () => { throw new Error("UCUM multiply is not used by the demo"); },
  () => { throw new Error("UCUM divide is not used by the demo"); },
);

// kotlin-logging inside the translator prints a banner on first use; in the terminal we hide just that line
function quiet(fn) {
  if (typeof process === "undefined" || !process.stdout) return fn();
  const write = process.stdout.write;
  let hidden = false; // println writes the text and the newline separately
  process.stdout.write = function (chunk, ...rest) {
    const text = String(chunk);
    if (text.startsWith("kotlin-logging:")) {
      hidden = !text.endsWith("\n");
      return true;
    }
    if (hidden && text === "\n") {
      hidden = false;
      return true;
    }
    hidden = false;
    return write.call(this, chunk, ...rest);
  };
  try { return fn(); } finally { process.stdout.write = write; }
}

/**
 * Compiles a set of libraries { "SymptomTriage": "<CQL text>", … }.
 * Returns { elm: { Name: json }, errors: [{ library, line, col, message }] }.
 * Included libraries are resolved from the same sources.
 */
export function compile(sources) {
  const models = new ModelManager();
  // Without SystemModelInfoProvider: “Could not resolve model name System”
  models.modelInfoLoader.registerModelInfoProvider(new SystemModelInfoProvider());
  models.modelInfoLoader.registerModelInfoProvider(
    createModelInfoProvider(id => (id === "FHIR" ? stringAsSource(FHIR_MODELINFO) : null)),
  );
  const libraries = new LibraryManager(models, undefined, undefined, ucumService);
  libraries.librarySourceLoader.registerProvider(
    createLibrarySourceProvider(id => (sources[id] != null ? stringAsSource(sources[id]) : null)),
  );

  const elm = {};
  const errors = [];
  for (const name of Object.keys(sources)) {
    const translator = quiet(() => CqlTranslator.fromText(sources[name], libraries));
    const errs = translator.errors.asJsArrayView();
    if (errs.length === 0) {
      elm[name] = JSON.parse(translator.toJson());
      continue;
    }
    for (const e of errs) {
      const at = String(e.locator ?? "").match(/startLine=(\d+), startChar=(\d+)/);
      errors.push({
        library: name,
        line: at ? Number(at[1]) : null,
        col: at ? Number(at[2]) + 1 : null,
        message: String(e.message),
      });
    }
  }
  return { elm, errors };
}

// ---------- scenario facts → FHIR ----------

const LOINC = "http://loinc.org";
const SNOMED = "http://snomed.info/sct";

// Shorthands for common facts: kind → code
const KINDS = {
  pain: { system: LOINC, code: "72514-3", display: "Pain severity 0-10" },
  phq9: { system: LOINC, code: "44261-6", display: "PHQ-9 total score" },
  "phq9-item9": { system: LOINC, code: "44260-8", display: "PHQ-9 item 9: thoughts of being better off dead or of self-harm" },
  gad7: { system: LOINC, code: "70274-6", display: "GAD-7 total score" },
  headache: { system: SNOMED, code: "25064002", display: "Headache" },
};

// Kinds whose code comes from the fact itself: a local question code or a SNOMED CT symptom
const CODE_SYSTEMS = {
  "headache-screen": "urn:example:cql-demo:headache",
  profile: "urn:example:cql-demo:profile",
  symptom: SNOMED,
};

// Answers with standard LOINC answer codes: yes/no and the PHQ frequency scale
const LOINC_ANSWERS = {
  Yes: "LA33-6",
  No: "LA32-8",
  "Not at all": "LA6568-5",
  "Several days": "LA6569-3",
  "More than half the days": "LA6570-1",
  "Nearly every day": "LA6571-9",
};

// An answer word without a standard code gets a local code, so answers that still need a mapping stay visible
const answerConcept = answer =>
  LOINC_ANSWERS[answer]
    ? { coding: [{ system: LOINC, code: LOINC_ANSWERS[answer], display: answer }] }
    : { coding: [{ system: "urn:example:cql-demo:answer", code: answer, display: answer }] };

function factCode(fact) {
  if (KINDS[fact.kind]) return { coding: [{ ...KINDS[fact.kind] }] };
  return { coding: [{ system: fact.system ?? CODE_SYSTEMS[fact.kind] ?? SNOMED, code: fact.code }] };
}

// One fact → one Observation. The source (Patient, RPM, MANUAL…) goes to meta.tag.
// The value is a number (value + unit), a coded answer (answer) or a date (date), or nothing at all:
// an Observation without a value is a question that was asked but not answered.
export function toObservation(fact, index) {
  return {
    resourceType: "Observation",
    id: fact.id ?? `fact-${index + 1}`,
    meta: { tag: [{ system: "urn:example:cql-demo:source", code: fact.source ?? "Patient" }] },
    status: fact.status ?? "final",
    code: factCode(fact),
    subject: { reference: "Patient/demo" },
    effectiveDateTime: fact.at,
    ...(fact.answer != null ? { valueCodeableConcept: answerConcept(fact.answer) } : {}),
    ...(fact.date != null ? { valueDateTime: fact.date } : {}),
    ...(fact.value != null
      ? {
          valueQuantity: {
            value: fact.value,
            unit: fact.unit ?? "{score}",
            system: "http://unitsofmeasure.org",
            code: fact.unit ?? "{score}",
          },
        }
      : {}),
  };
}

// The patient's bundle: the Patient (birthDate and anything else from `patient`), any ready-made
// FHIR resources from `resources` (the patient background) and one Observation per fact
export function toBundle(scenario) {
  const patient = { ...(scenario.patient ?? {}), resourceType: "Patient", id: "demo" };
  if (scenario.birthDate) patient.birthDate = scenario.birthDate;
  return {
    resourceType: "Bundle",
    type: "collection",
    entry: [
      { resource: patient },
      ...(scenario.resources ?? []).filter(r => r && r.resourceType !== "Patient").map(resource => ({ resource })),
      ...(scenario.facts ?? []).map((f, i) => ({ resource: toObservation(f, i) })),
    ],
  };
}

// Any ISO time (…Z or …+03:00) → an engine DateTime in UTC
const utc = iso => cql.DateTime.fromJSDate(new Date(iso), 0);

// ---------- execution ----------

/** Runs the rule for the scenario's patient. Returns { pass, failures, trace }. */
export async function runScenario(elm, rule, scenario, vocabulary) {
  const repository = new cql.Repository(Object.fromEntries(Object.entries(elm).filter(([name]) => name !== rule)));
  const library = new cql.Library(elm[rule], repository);
  const codes = new cql.CodeService(Object.fromEntries(Object.entries(vocabulary).map(([url, list]) => [url, { "": list }])));

  const patients = cqlfhir.PatientSource.FHIRv401();
  patients.loadBundles([toBundle(scenario)]);

  // Always pass every parameter, null included: without a value cql-execution 3.3.2 substitutes the parameter's definition for null
  const parameters = {
    "Last Run": scenario.lastRun ? utc(scenario.lastRun) : null,
    "Current Level": scenario.currentLevel ?? null,
  };

  const results = await new cql.Executor(library, codes, parameters).exec(patients, utc(scenario.now));
  const values = results.patientResults.demo;

  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const failures = Object.entries(scenario.expect ?? {})
    .filter(([step, want]) => !same(plain(values[step]), want))
    .map(([step, want]) => ({ step, expected: want, got: plain(values[step]) }));
  const trace = Object.entries(values)
    .filter(([step]) => step !== "Patient")
    .map(([step, value]) => [step, show(value)]);
  return { pass: failures.length === 0, failures, trace };
}

// The value compared with expect: a number, string, boolean, null, or a list of those
const plain = v => (Array.isArray(v) ? v.map(plain) : v != null && typeof v === "object" && "value" in v ? v.value : v ?? null);

const isPrimitive = v => v == null || ["string", "number", "boolean"].includes(typeof v);

// The value shown in the trace: short, and showing which fact was picked
function show(v) {
  if (v == null) return "null";
  if (typeof v.unit === "string" && typeof v.value === "number") return `${v.value} '${v.unit}'`;
  if (Array.isArray(v)) return v.every(isPrimitive) ? `[${v.join(", ")}]` : `${v.length} fact(s)`;
  if (v.low !== undefined && v.high !== undefined) return `[${v.low} .. ${v.high}]`;
  if (v.id && v.effective) return `Observation/${v.id.value ?? v.id} at ${v.effective.value ?? v.effective}`;
  return String(v.value ?? v);
}
