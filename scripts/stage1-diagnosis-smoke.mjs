#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, "..");
const manifestPath = resolve(repoRoot, "docs/clinical-test-cases/stage1-diagnosis-cases.json");
const bundleModuleUrl = pathToFileURL(
  resolve(repoRoot, "../rehmp/ehmp-ui/rehmp-cprs-demo/writeback/writebackBundle.js"),
).href;

const { buildReminderWritebackBundle, validateWritebackBundle, summarizeBundle } = await import(bundleModuleUrl);

const args = parseArgs(process.argv.slice(2));
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const selectedCaseIds = caseIds(args);
const selectedCases = selectedCaseIds.length
  ? manifest.cases.filter((item) => selectedCaseIds.includes(item.id))
  : manifest.cases;

if (!selectedCases.length) {
  fail(`No cases matched: ${selectedCaseIds.join(", ")}`);
}

const missing = selectedCaseIds.filter((id) => !manifest.cases.some((item) => item.id === id));
if (missing.length) {
  fail(`Unknown case id(s): ${missing.join(", ")}`);
}

const shouldPost = Boolean(args.post || process.env.STAGE1_POST === "1");
const baseUrl = String(args.baseUrl || process.env.STAGE1_BASE_URL || "http://127.0.0.1:9085").replace(/\/$/, "");
const dfn = String(args.dfn || process.env.STAGE1_DFN || "418");
const patientName = String(args.patientName || process.env.STAGE1_PATIENT_NAME || `DFN ${dfn}`);

const results = [];
for (const testCase of selectedCases) {
  const bundle = buildBundle(testCase, { dfn, patientName });
  const issues = validateWritebackBundle(bundle);
  const summary = summarizeBundle(bundle);
  const localChecks = checkBundle(testCase, bundle);
  const dryRunOk = issues.length === 0 && localChecks.length === 0;
  const result = {
    id: testCase.id,
    title: testCase.title,
    mode: shouldPost ? "post" : "dry-run",
    bundle: {
      entries: summary.entries,
      resources: summary.resources,
      reasonCodeCount: encounterResource(bundle)?.reasonCode?.length || 0,
      conditionCount: resourceCount(bundle, "Condition"),
    },
    checks: {
      validBundle: issues.length === 0,
      issues,
      localChecks,
    },
  };
  if (shouldPost) {
    result.post = await postBundle(bundle, `${baseUrl}/updatepatient?dfn=${encodeURIComponent(dfn)}&load=1&returngraph=1`);
    result.writeback = summarizeWriteback(result.post.body, testCase);
    if (!result.writeback.conditionLoaded) {
      result.checks.localChecks.push(`Expected Condition to load: ${result.writeback.conditionMessage || "no message returned"}`);
    }
  }
  results.push(result);
  const status = shouldPost
    ? result.post.ok && result.writeback.encounterLoaded && result.writeback.conditionLoaded ? "PASS" : "FAIL"
    : dryRunOk ? "PASS" : "FAIL";
  console.log(`${status} ${testCase.id}: ${testCase.title}`);
  if (!dryRunOk) {
    for (const issue of [...issues, ...localChecks]) console.log(`  - ${issue}`);
  }
  if (shouldPost) {
    console.log(`  POST ${result.post.status} ${result.post.statusText}`);
    console.log(`  Encounter loaded: ${result.writeback.encounterLoaded}`);
    console.log(`  Standard codes queued: ${result.writeback.standardCodeCount}`);
    console.log(`  Visit IEN: ${result.writeback.visitIen || "not returned"}`);
  }
}

const failed = results.filter((item) =>
  item.checks.issues.length ||
  item.checks.localChecks.length ||
  (shouldPost && (!item.post.ok || !item.writeback.encounterLoaded)),
);

if (args.json) {
  console.log(JSON.stringify({ baseUrl, dfn, post: shouldPost, results }, null, 2));
}

if (failed.length) {
  process.exitCode = 1;
}

function buildBundle(testCase, patient) {
  const diagnoses = [
    diagnosisSelection(testCase, testCase.diagnosis.snomedCode, testCase.diagnosis.display, {
      icd10Code: testCase.diagnosis.icd10Code,
      icd10Display: testCase.diagnosis.icd10Display,
      fileable: true,
      isPov: testCase.povCode === testCase.diagnosis.snomedCode,
      addToProblemList: Boolean(testCase.addToProblemList),
      supportText: testCase.noteSupport,
    }),
    ...testCase.selectedFindings.map((finding) =>
      diagnosisSelection(testCase, finding.code, finding.display, {
        fileable: false,
        isPov: testCase.povCode === finding.code,
        supportText: testCase.noteSupport,
      }),
    ),
  ];
  const encounterDefaults = manifest.defaults?.encounter || {};
  const noteContent = stage1NoteContent(testCase, diagnoses);
  return buildReminderWritebackBundle({
    requestId: `stage1-${testCase.id}-${Date.now()}`,
    patient: {
      dfn: patient.dfn,
      displayName: patient.patientName,
      patientReference: `Patient/${patient.dfn}`,
    },
    encounter: {
      ...encounterDefaults,
      reasonText: testCase.title,
      locationDisplay: `${encounterDefaults.locationDisplay || "VEHU clinic"} (${testCase.id})`,
    },
    note: {
      title: `STAGE 1 DIAGNOSIS TEST - ${testCase.title.toUpperCase()}`,
      content: noteContent,
    },
    diagnoses,
  });
}

function stage1NoteContent(testCase, diagnoses) {
  const supportLines = diagnoses.flatMap((diagnosis) => [
    `- ${diagnosis.display}${diagnosis.code ? ` (SCT ${diagnosis.code})` : ""}`,
    `  Support: ${diagnosis.supportText}`,
    `  Role: ${diagnosisRoleText(diagnosis)}`,
  ]);
  return (
    `Stage 1 diagnosis writeback smoke test for ${testCase.title}.\n\n` +
    `Patient selection hint: ${testCase.plausiblePatientHint}\n\n` +
    `${testCase.noteSupport}\n\n` +
    `Diagnosis / Findings Support:\n${supportLines.join("\n")}`
  );
}

function diagnosisRoleText(diagnosis) {
  const roles = [];
  if (diagnosis.isPov) {
    roles.push(diagnosis.fileable ? "V POV" : "Encounter standard code selected as POV source");
  } else {
    roles.push(diagnosis.fileable ? "Mapped diagnosis" : "Encounter standard code");
  }
  if (diagnosis.addToProblemList) {
    roles.push("Problem List requested");
  }
  return roles.join("; ");
}

function diagnosisSelection(testCase, code, display, extra = {}) {
  return {
    code: String(code),
    display,
    system: manifest.defaults?.system || "http://snomed.info/sct",
    fileable: false,
    addToProblemList: false,
    isPov: false,
    supportText: testCase.noteSupport,
    ...extra,
  };
}

function checkBundle(testCase, bundle) {
  const issues = [];
  const encounter = encounterResource(bundle);
  if (!encounter) {
    return ["Bundle is missing Encounter resource."];
  }
  const reasonCodes = Array.isArray(encounter.reasonCode) ? encounter.reasonCode : [];
  const expectedReasonCodeCount = 1 + testCase.selectedFindings.length;
  if (reasonCodes.length !== expectedReasonCodeCount) {
    issues.push(`Expected ${expectedReasonCodeCount} Encounter.reasonCode entries, got ${reasonCodes.length}.`);
  }
  const povCount = reasonCodes.filter((item) =>
    (item.extension || []).some((extension) =>
      extension.url === "http://vistaplex.org/fhir/StructureDefinition/vista-pov-primary" &&
      extension.valueBoolean === true,
    ),
  ).length;
  if (povCount !== 1) {
    issues.push(`Expected exactly one vista-pov-primary reasonCode extension, got ${povCount}.`);
  }
  const conditionCount = resourceCount(bundle, "Condition");
  const expectedConditionCount = testCase.expectedWriteback?.condition ? 1 : 0;
  if (conditionCount !== expectedConditionCount) {
    issues.push(`Expected ${expectedConditionCount} Condition resources, got ${conditionCount}.`);
  }
  const noteText = encounter.note?.[0]?.text || "";
  if (!noteText.includes("Diagnosis / Findings Support")) {
    issues.push("Encounter.note is missing Diagnosis / Findings Support section.");
  }
  for (const selection of [testCase.diagnosis, ...testCase.selectedFindings]) {
    const display = selection.display;
    if (display && !noteText.includes(display)) {
      issues.push(`Encounter.note is missing selected display text: ${display}`);
    }
  }
  return issues;
}

async function postBundle(bundle, url) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/fhir+json",
      Accept: "application/json",
    },
    body: JSON.stringify(bundle),
  });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { rawBody: text };
  }
  return {
    ok: response.ok && body.status !== "error",
    status: response.status,
    statusText: response.statusText,
    body,
  };
}

function summarizeWriteback(body, testCase) {
  const transactionLoad = Array.isArray(body?.transactionLoad) ? body.transactionLoad : [];
  const encounterLoad = transactionLoad.map((item) => item.Encounter).find(Boolean) || body?.domains?.Encounter || {};
  const conditionLoad = transactionLoad.map((item) => item.Condition).find(Boolean) || body?.domains?.Condition || {};
  const standardCodes = Array.isArray(encounterLoad.standardCode)
    ? encounterLoad.standardCode
    : Object.values(encounterLoad.standardCode || {}).filter((item) => item && typeof item === "object");
  const expectCondition = Boolean(testCase.expectedWriteback?.condition);
  const conditionLoaded = !expectCondition || body?.domains?.Condition?.status === "loaded" || conditionLoad.loadStatus === "loaded";
  return {
    encounterLoaded: body?.domains?.Encounter?.status === "loaded" || encounterLoad.loadStatus === "loaded",
    conditionLoaded,
    conditionMessage: body?.domains?.Condition?.message || conditionLoad.message || "",
    visitIen: body?.domains?.Encounter?.visitIen || encounterLoad.visitIen || "",
    standardCodeCount: standardCodes.length,
    expectedStandardCodeCount: testCase.expectedWriteback?.standardCodeCount || 0,
    povStatus: encounterLoad.pov?.status || "",
    message: body?.domains?.Encounter?.message || encounterLoad.message || "",
  };
}

function encounterResource(bundle) {
  return (bundle.entry || []).map((entry) => entry.resource).find((resource) => resource?.resourceType === "Encounter");
}

function resourceCount(bundle, resourceType) {
  return (bundle.entry || []).filter((entry) => entry.resource?.resourceType === resourceType).length;
}

function caseIds(args) {
  const fromEnv = process.env.STAGE1_CASE
    ? process.env.STAGE1_CASE.split(",").map((item) => item.trim()).filter(Boolean)
    : [];
  return [...fromEnv, ...args.caseIds];
}

function parseArgs(argv) {
  const parsed = { caseIds: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--case") {
      parsed.caseIds.push(requiredValue(argv, ++index, arg));
    } else if (arg === "--dfn") {
      parsed.dfn = requiredValue(argv, ++index, arg);
    } else if (arg === "--patient-name") {
      parsed.patientName = requiredValue(argv, ++index, arg);
    } else if (arg === "--base-url") {
      parsed.baseUrl = requiredValue(argv, ++index, arg);
    } else if (arg === "--post") {
      parsed.post = true;
    } else if (arg === "--dry-run") {
      parsed.post = false;
    } else if (arg === "--json") {
      parsed.json = true;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      fail(`Unknown argument: ${arg}`);
    }
  }
  return parsed;
}

function requiredValue(argv, index, flag) {
  const value = argv[index];
  if (!value || value.startsWith("--")) {
    fail(`${flag} requires a value.`);
  }
  return value;
}

function printHelp() {
  console.log(`Usage: node scripts/stage1-diagnosis-smoke.mjs [options]

Options:
  --dry-run              Validate generated bundles without posting (default)
  --post                 POST bundles to /updatepatient
  --case <id>            Run one case; can be repeated
  --dfn <dfn>            Target patient DFN (default STAGE1_DFN or 418)
  --patient-name <name>  Display name for generated Patient resource
  --base-url <url>       Server base URL (default STAGE1_BASE_URL or http://127.0.0.1:9085)
  --json                 Print JSON summary after line-oriented output
`);
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
