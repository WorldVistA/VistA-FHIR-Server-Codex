# Clinical diagnosis test case deployment plan

## Purpose

This document turns the 12 proposed common clinical conditions into a staged test
strategy for the current diagnosis picker, encounter note, and C0FW writeback
work.

The first useful test is not a full synthetic chart. It is a focused clinical
writeback fixture:

- one encounter;
- one generated note with explicit diagnosis/finding support;
- one or more selected SNOMED CT codes on `Encounter.reasonCode`;
- at most one selected code marked as the V POV candidate;
- optional encounter-linked `Condition` filing only when an ICD-10-CM mapping is
  available and the fixture asks for Condition/problem-list semantics.

After that path is reliable, the same conditions can be expanded into full EHR
validation bundles with LOINC-coded observations, RxNorm medication orders, and
additional procedures or imaging results.

## Why stage this

The submitted clinical cases are good clinical scenarios, but the coding layers
should not all enter the first test at once.

Diagnosis and finding support are the capabilities currently being built:

- C0T/C0RG searches terminology and returns selectable SNOMED concepts with
  `fileable` metadata.
- The CPRS demo can select multiple diagnosis/finding codes for one encounter.
- The writeback bundle can put every selected code on `Encounter.reasonCode`.
- C0FW can file SNOMED-only selected codes as V STANDARD CODES through
  `ENCDATA("STD CODES",...)`.
- A mapped diagnosis can be represented as an encounter-linked `Condition` for
  V POV or problem-list filing.

Vitals, labs, medications, imaging, and assessment scores belong in the next
fixture layer. Those should use their native FHIR resources and code systems
rather than forcing everything through the diagnosis interaction.

## Stage 1: diagnosis and note support fixtures

Stage 1 should exercise the new multi-code diagnosis picker and C0FW Encounter
import.

Each test case should define:

- `id`: stable short identifier, for example `t2dm-basic`;
- `title`: clinical condition title;
- `diagnosis`: ICD-10-CM plus SNOMED CT diagnosis code;
- `selectedFindings`: one or more SNOMED CT finding codes selected in the UI;
- `povCode`: exactly one selected code marked as the V POV candidate;
- `addToProblemList`: true only when the mapped diagnosis should become a
  problem-list entry;
- `noteSupport`: short text that explains why the diagnosis is supported;
- `expectedWriteback`: expected C0FW behavior.

For the first pass, use the diagnosis SNOMED code plus one or two clinically
obvious manifestation SNOMED codes. The full medication/lab/vital story can be
summarized in note text, but not yet filed as structured Observation or
MedicationRequest resources.

### Expected Stage 1 bundle shape

The CPRS demo should generate a transaction bundle with:

- `Patient`;
- `Encounter` with `note[]`;
- `Encounter.reasonCode[]`, one entry per selected diagnosis/finding code;
- `vista-pov-primary=true` extension on exactly one `reasonCode` entry;
- optional `Condition` when the selected row is ICD-mapped and has Condition
  semantics;
- any reminder `Questionnaire` / `QuestionnaireResponse` entries already used by
  the demo.

For SNOMED-only findings, the expected backend result is:

- no `Condition` solely for that finding;
- `C0FWENC` queues an `ENCDATA("STD CODES",n,...)` row;
- VistA persists a row in V STANDARD CODES (`^AUPNVSC`) for the visit.

For the one mapped V POV candidate:

- if ICD-10 is present and resolvable, C0FW may queue `DX/PL` as the visit POV;
- if only SNOMED is present, C0FW should keep it as a standard code and log that
  true V POV requires ICD mapping.

## Stage 1 condition set

These are the first-pass clinical writeback fixtures. The `selectedFindings`
column should be interpreted as UI-selected SNOMED concepts for
`Encounter.reasonCode`, not as fully modeled structured observations.

| ID | Condition | Diagnosis coding | Suggested selected findings for Stage 1 | Stage 1 expected behavior |
| --- | --- | --- | --- | --- |
| `htn-basic` | Essential hypertension | ICD-10 `I10`; SNOMED CT `38341003` Essential hypertension | `38341003` Essential hypertension; `24184005` Blood pressure above reference range; optional `330007` Occipital headache | Hypertension can be mapped as the V POV/Condition; elevated BP and headache should also file as encounter standard codes. |
| `t2dm-basic` | Type 2 diabetes mellitus | ICD-10 `E11.9`; SNOMED CT `44054006` Type 2 diabetes mellitus | `44054006` Type 2 diabetes mellitus; `56574000` Polyuria; `17173007` Polydipsia; optional `414916001` Obesity | Type 2 diabetes can be mapped as V POV/Condition; symptoms and obesity are supporting standard codes. |
| `cap-acute` | Community-acquired pneumonia | ICD-10 `J18.9`; SNOMED CT `385093006` Community acquired pneumonia | `385093006` Community acquired pneumonia; `386661006` Fever; `267036007` Dyspnea; `409609008` Pulmonary infiltrate | Pneumonia diagnosis should be verified locally; findings file as standard codes. |
| `hypothyroid-primary` | Hypothyroidism | ICD-10 `E03.9`; SNOMED CT `40930008` Hypothyroidism | `40930008` Hypothyroidism; `214264003` Lethargy; `8943002` Weight gain; `80585000` Intolerant of cold | Diagnosis can be V POV/Condition if local mapping resolves; findings file as standard codes. |
| `cystitis-acute` | Acute cystitis | ICD-10 `N30.00`; SNOMED CT `68226007` Acute cystitis | `68226007` Acute cystitis; `49650001` Dysuria; `162116003` Urinary frequency; `162053006` Suprapubic pain | Acute cystitis should be verified locally; urinary symptoms file as standard codes. |
| `hyperlipidemia-basic` | Hyperlipidemia | ICD-10 `E78.5`; SNOMED CT `55822004` Hyperlipidemia | `55822004` Hyperlipidemia; `67335000` Asymptomatic; optional cholesterol-related finding if terminology search returns one | Diagnosis can be V POV/Condition; avoid over-modeling lipid lab results until Stage 2. |
| `copd-basic` | COPD | ICD-10 `J44.9`; SNOMED CT `13645005` Chronic obstructive lung disease | `13645005` Chronic obstructive lung disease; `68154008` Chronic cough; `28743005` Productive cough; `60845006` Dyspnea on exertion | COPD can be V POV/Condition; respiratory manifestations file as standard codes. |
| `iron-def-anemia` | Iron deficiency anemia | ICD-10 `D50.9`; SNOMED CT `87522002` Iron deficiency anemia | `87522002` Iron deficiency anemia; `84229001` Fatigue; `13791008` Generalized weakness; `267029006` Pallor | Anemia can be V POV/Condition; findings file as standard codes. |
| `appendicitis-acute` | Acute appendicitis | ICD-10 `K35.80`; SNOMED CT `85189001` Acute appendicitis | `85189001` Acute appendicitis; `301754002` Right lower quadrant pain; `43478001` Abdominal tenderness | Diagnosis can be V POV/Condition; localized findings file as standard codes. |
| `ckd-stage-3` | Chronic kidney disease stage 3 | ICD-10 `N18.30`; SNOMED CT `433144002` Chronic kidney disease stage 3 | `433144002` Chronic kidney disease stage 3; `84229001` Fatigue; `139394000` Nocturia; optional `271809000` Peripheral edema | CKD stage 3 can be V POV/Condition; symptoms file as standard codes. |
| `mdd-recurrent-moderate` | Major depressive disorder, recurrent, moderate | ICD-10 `F33.1`; SNOMED CT `191611001` Recurrent major depressive episodes, moderate | `191611001` Recurrent major depressive episodes, moderate; `366979004` Depressed mood; `193462001` Insomnia; `28669007` Anhedonia | Diagnosis mapping should be verified locally; symptoms file as standard codes. |
| `gout-flare` | Acute gout flare | ICD-10 `M10.9`; SNOMED CT `90560007` Gout | `90560007` Gout; `67148009` Podagra; `247441003` Erythema of joint; `271771009` Joint swelling | Gout can be V POV/Condition; flare findings file as standard codes. |

## Stage 1 validation goals

For each case, run the same checks:

1. Search the diagnosis term through C0T/C0RG terminology search in the target
   environment.
2. Confirm the UI result includes the full SNOMED display text and correct
   `fileable` / mapping metadata.
3. Select the diagnosis plus one or more supporting finding codes.
4. Mark exactly one code as the V POV candidate.
5. Generate the note and confirm it contains every selected display string in a
   `Diagnosis / Findings Support` section.
6. Confirm the bundle includes one `Encounter.reasonCode[]` entry per selected
   code.
7. POST to `/updatepatient?dfn=<dfn>&load=1&returngraph=1`.
8. Confirm C0FW load output shows every SNOMED-only finding under
   `Encounter.standardCode`.
9. Confirm V STANDARD CODES rows exist on the visit.
10. If a mapped Condition was requested, confirm at most one POV/problem-list
    path was filed.

## Stage 2: structured clinical evidence bundles

After Stage 1 is stable, add separate fixture bundles that produce the clinical
manifestations.

These should not be forced into the diagnosis picker. They should use the normal
FHIR resource for the kind of evidence:

- blood pressure, pulse, respiratory rate, oxygen saturation, BMI, and
  temperature as vital-sign `Observation` resources;
- HbA1c, glucose, potassium, TSH, free T4, urinalysis, cholesterol, LDL,
  hemoglobin, ferritin, creatinine, eGFR, uric acid, WBC, and neutrophils as
  LOINC-coded laboratory `Observation` resources;
- PHQ-9 score as an assessment `Observation` or questionnaire-derived score;
- spirometry as an `Observation` or `DiagnosticReport` with component
  observations;
- medication therapy as concrete `MedicationRequest` resources using RxNorm or
  locally mappable drug codes;
- chest imaging as `ServiceRequest` / `DiagnosticReport` with a coded finding;
- appendicitis surgery workup or antibiotics as `ServiceRequest`, `Procedure`,
  and `MedicationRequest` resources as appropriate.

Stage 2 expected behavior should validate import/readback and display, not the
diagnosis picker itself.

## Stage 2 examples by condition

- Hypertension: LOINC systolic/diastolic blood pressure observations; RxNorm
  lisinopril `MedicationRequest`; optional potassium/creatinine monitoring.
- Type 2 diabetes: LOINC HbA1c and fasting glucose observations; RxNorm
  metformin `MedicationRequest`; BMI observation.
- Pneumonia: temperature, respiratory rate, WBC observation, chest imaging
  report, antibiotic `MedicationRequest`.
- Hypothyroidism: TSH and free T4 observations; levothyroxine
  `MedicationRequest`.
- Acute cystitis: urinalysis nitrite and leukocyte esterase observations;
  nitrofurantoin or TMP-SMX `MedicationRequest`.
- Hyperlipidemia: total cholesterol and LDL observations; statin
  `MedicationRequest`.
- COPD: oxygen saturation and spirometry observations; bronchodilator
  `MedicationRequest`; smoking history can be represented as a social-history
  observation or Health Factor fixture if local filing is the target.
- Iron deficiency anemia: hemoglobin, ferritin, and RBC morphology observations;
  oral iron `MedicationRequest`.
- Appendicitis: fever/WBC observations, abdominal exam findings, imaging report,
  IV fluids/antibiotic orders, surgical consult/procedure fixture.
- CKD stage 3: eGFR and creatinine observations across time; edema finding;
  ARB `MedicationRequest`; NSAID avoidance in note/care plan.
- Depression: PHQ-9 score, symptom findings, SSRI `MedicationRequest`, normal
  TSH observation as rule-out evidence.
- Gout flare: uric acid observation; joint findings; colchicine or NSAID
  `MedicationRequest`.

## Deployment approach

### 1. Build a fixture manifest

Create a manifest file with one row per test case. Each row should include the
Stage 1 diagnosis/finding selections and expected filing outcomes. Keep Stage 2
evidence fixture metadata separate so a diagnosis test can run without a full
synthetic chart.

Suggested future files:

- `docs/clinical-test-cases/stage1-diagnosis-cases.json`
- `docs/clinical-test-cases/stage2-evidence-fixtures.json`
- `docs/clinical-test-cases/README.md`

### 2. Load Stage 1 through the CPRS demo first

Use the active CPRS demo against `vehu10`:

- open `/fhir` through the gateway;
- pick a known VEHU patient who is clinically plausible for the case;
- open `rehmp`;
- use the diagnosis picker to select one case's diagnosis and findings;
- post to `/updatepatient`;
- save the writeback artifact for comparison.

This is the best first deployment because it exercises the exact user-facing
workflow.

Do not plan on cleanup as the normal test loop. Treat filed visits, standard
codes, notes, and saved writeback artifacts as an audit trail for readback
validation. When a patient becomes too messy to interpret, pick a new plausible
test patient rather than trying to unwind prior clinical filing.

Patient selection should be part of the fixture. Prefer patients whose existing
chart makes the scenario believable:

- chronic metabolic/cardiovascular cases: older adult patients with prior
  outpatient encounters, medications, or related chronic problems;
- pneumonia, cystitis, appendicitis, and gout flare: patients with recent
  outpatient or emergency-style encounters and enough context for an acute visit;
- depression: patients with note history where behavioral-health-style support
  text would not look out of place;
- CKD/anemia: patients with lab-heavy histories when available.

If no clearly plausible existing patient is available, generate or import a new
synthetic patient for that case and then reuse that patient until the accumulated
test history becomes noisy.

### 3. Add a scripted Stage 1 smoke runner

Once the UI flow works, add a small Node smoke script in the CPRS demo or Codex
scripts that:

- reads the Stage 1 manifest;
- calls `buildReminderWritebackBundle({ diagnoses: [...] })`;
- POSTs each bundle to `/updatepatient?dfn=<test-dfn>&load=1&returngraph=1`;
- checks the returned graph for expected `standardCode`, `pov`, and `Condition`
  statuses;
- optionally verifies `^AUPNVSC("AD",visit,ien)` on `vehu10`.

Start with two cases:

- one chronic mapped diagnosis such as Type 2 diabetes;
- one acute mapped diagnosis with several findings such as pneumonia or cystitis.

Then expand to all 12.

### 4. Promote to the four environments

After `vehu10` is stable, use the same manifest against:

- local `fhir`;
- local `vehu10`;
- `devfhir.vistaplex.org`;
- `fhir.vistaplex.org`.

Use plausible existing DFNs or generated patients per environment. Do not reuse a
single patient forever; rotate to a fresh plausible patient when previous
writeback history makes the case hard to read. Record:

- terminology search result availability;
- ICD mapping availability;
- whether SNOMED standard codes filed;
- whether V POV filed;
- whether problem-list add was requested and filed;
- readback behavior in `/fhir` and the CPRS demo.

### 5. Add Stage 2 evidence bundles

Only after Stage 1 is repeatable, create fixture bundles for the supporting
observations and medications. These fixtures should be deployed independently
from diagnosis selection so failures are easier to isolate:

- one diagnosis writeback bundle;
- one evidence bundle for observations/medications/procedures;
- one readback assertion set.

## Open questions

- Which DFNs are currently assigned to each diagnosis-writeback test case in each
  environment, and when should a case rotate to a fresh plausible patient?
- Should Stage 1 problem-list add be enabled for chronic conditions only
  (`I10`, `E11.9`, `J44.9`, `N18.30`, depression), and disabled for acute
  conditions by default?
- Should Stage 1 use only terms returned by C0T search, or allow a static
  manifest to seed the picker when a local terminology server lacks a code?
- How should scripted smokes record patient selection and accumulated writeback
  history so a tester can decide when a patient has become too messy?
- For Stage 2, which import path owns LOINC/RxNorm fixtures in C0FW versus SYN?

## Recommended next step

Create the Stage 1 manifest and run two hand-driven UI tests in `vehu10`:

1. Type 2 diabetes with polyuria and polydipsia, diagnosis marked as V POV and
   problem-list add enabled.
2. Pneumonia with fever and dyspnea, diagnosis marked as V POV and problem-list
   add disabled.

If both cases file cleanly and read back as expected, automate the remaining 10
Stage 1 cases before starting the LOINC/RxNorm evidence fixtures.
