# Consequential User Decisions

Generated: 2026-06-24T04:37:34Z

This document ranks the user statements that most changed the RPMS/Codex FHIR
project direction. "Consequential" means the statement changed architecture,
corrected a wrong assumption, constrained a risky implementation path, or
unlocked a reusable validation/demo workflow.

## Methodology And Accounting

- Source material: the prior project transcript plus the compacted context
  available in the current session.
- Subagents used: 2.
  - One subagent analyzed the full transcript and ranked user directives.
  - One subagent independently explored the RPMS allergy implementation path.
- Parent-agent work: reviewed the subagent findings against the current RPMS
  work and added recent decisions that were preserved in compacted context.
- Wall-clock time: about 36 minutes from subagent launch to this document draft.
- Token accounting: unavailable. Cursor did not expose token counts for the
  parent agent or subagents, so exact token usage could not be recorded.
- Timestamp limitation: older transcript entries include exact timestamps.
  Several late RPMS/vitals statements are preserved in compacted context without
  exact event timestamps; those are marked approximate.

## Ranked Decisions

### 1. Native C0FW/C0FHIR Should Own Current Implementation

Date/time: May 13, 2026 2:37 PM and 11:08 PM UTC-4

Key wording:

- "enhance C0FW so that /addpatient does not need to use any SYN or ISI routines"
- "make C0FW whole by allowing selective use of SYN and ISI"
- "HealthFactors can be handled under Encounter"

Why it mattered: this made C0FW the durable route owner and moved SYN/ISI from
default import engines to explicit, selective fallback tools.

Implications:

- `/addpatient` and `/updatepatient` are C0FW-owned.
- C0FW policy selects native/SYN/ISI/off per domain.
- Health Factors are Encounter-scoped facts, not invented FHIR resource types.
- Missing legacy routines should produce explicit status, not hidden crashes.

### 2. Use Current Versions, Not Legacy SYN/ISI By Default

Date/time: approximate, early RPMS implementation-plan phase

Key wording: "make sure we are implementing our current versions (C0FHIR C0FW
etc) and only using SYN and ISI where necessary"

Why it mattered: this converted the RPMS plan from "install whatever the old
loader used" into a modern Codex-first implementation.

Implications:

- The implementation plan needed a manifest of installed current C0F/C0FW
  routines.
- SYN and ISI became reference material and narrow fallback, especially while
  labs, meds, and procedures were deferred.
- Each RPMS domain has to prove native storage/readback before becoming default.

### 3. CPRS Demo Is The Current UI Surface

Date/time: May 16, 2026 12:45 PM UTC-4

Key wording: "the cprs demo is the one that is current, and will be for a long
time... start by opening /fhir... click on rehmp... to get to the cprs demo"

Why it mattered: it fixed the demo contract and removed ambiguity among the
archived FHIR/RPC demos.

Implications:

- `/fhir` patient index is the entry point.
- `rehmp` links launch CPRS for that patient.
- Gateway scripts and workspace rules now target the current CPRS demo path.
- Demo validation has to pass through the same UI path the user will inspect.

### 4. RPMS Data Must Land Where RPMS Itself Reads It

Date/time: approximate, Jun 22-23, 2026

Key wording:

- "please check our reference rpms... see where it store the vitals"
- "we may be doing it in a place that the rest of rpms doesn't know about"

Why it mattered: this exposed the vitals storage mismatch. The code had filed
VistA-style vitals in `^GMR(120.5)`, while RPMS PCC/readback expected
`^AUPNVMSR`.

Implications:

- `C0FWVIT` was changed to file RPMS-native `V MEASUREMENT` rows.
- `C0FHIRD` was changed to read RPMS vitals through the RPMS measurement path.
- The same reference-RPMS check became the model for Problems, Immunizations,
  and Allergies.

### 5. No Dual Write For Vitals

Date/time: approximate, Jun 22-23, 2026

Key wording: "no dual write"

Why it mattered: it prevented a compatibility shim that would have hidden the
real RPMS target-store decision.

Implications:

- Vitals are not written to both `^GMR(120.5)` and `^AUPNVMSR`.
- RPMS behavior is fixed by using the native RPMS store, not by duplicating data.
- Readback and UI validation must rely on the RPMS-native path.

### 6. Fix Before Rebuild

Date/time: approximate, Jun 22-23, 2026

Key wording: "we can rebuild after you fix it"

Why it mattered: it kept the work focused on correcting the implementation
before resetting the environment.

Implications:

- The vitals defect was debugged in-place before any rebuild.
- DFN 4 was repaired by reposting the source bundle after the native vitals fix.
- The rebuild became a validation step, not a way to erase a poorly understood
  failure.

### 7. TJSON Should Behave The Same On RPMS As Vista

Date/time: approximate, Jun 2026

Key wording:

- "there is no reason rpms should use tjson differently than vista"
- "you're wrong... there are many longer text objects on vehu10 and devfhir...
  and they never fail"

Why it mattered: it corrected an overfitted RPMS explanation for browser/TJSON
failures.

Implications:

- The fix had to preserve parity with Vista/devfhir behavior.
- Long note text was not accepted as an RPMS-specific limitation.
- Browser and FHIR serialization fixes had to be made in shared code paths.

### 8. DATA2PCE Should Own Core Encounter Filing Where It Can

Date/time: May 27, 2026 1:50 PM and Jun 2, 2026 5:42 PM UTC-4

Key wording:

- "DATA2PCE supports the fileing of SNOMED codes"
- "I'm uncomfortable going around DATA2PCE"
- "Let's try and create the encounter with one call to DATA2PCE"

Why it mattered: it rejected direct FileMan/global shortcuts for PCE facts when
the package API could do the filing.

Implications:

- Encounter diagnosis/finding work centered around `DATA2PCE^PXAI`.
- SNOMED/V STANDARD CODES behavior had to be inspected through package APIs.
- Direct writes are reserved for domains where RPMS reference behavior requires
  them, such as RPMS vitals.

### 9. Multi-Code Diagnosis Requires One V POV Plus Findings

Date/time: May 27, 2026 1:58 PM UTC-4

Key wording: "only one of them can be V POV... checkbox in addition to the 'add
to Problem list' checkbox"

Why it mattered: it clarified the difference between a primary encounter
diagnosis, supporting SNOMED findings, and optional Problem List creation.

Implications:

- CPRS UI needed multi-code selection.
- Backend writeback had to distinguish one primary V POV from additional
  reason/finding codes.
- Problem List filing became explicit user intent, not an automatic side effect.

### 10. Diagnosis Selection Must Be Bundled With Encounter And Note

Date/time: May 26, 2026 3:30 PM UTC-4

Key wording: diagnosis selection must be bundled "in an encounter with a note,"
support text, and optional problem-list Condition.

Why it mattered: it defined the CPRS writeback contract, not just a terminology
picker.

Implications:

- The UI writes Encounter, note text, selected diagnosis support, and optional
  Condition together.
- Backend filing has to preserve context and source support text.
- Tests had to validate the whole writeback workflow, not an isolated code
  search result.

### 11. Terminology Needs A Gateway Strategy

Date/time: May 26, 2026 5:26 PM and 7:29 PM UTC-4

Key wording:

- "use the vista-rpms MCP... how RPMS uses the BSTS terminology server"
- "implement a terminology server gateway"
- "create a worldvista/C0T-terminology-gateway repo"

Why it mattered: it moved diagnosis search/mapping from ad hoc local lookup to a
deliberate terminology gateway design.

Implications:

- C0T became a separate terminology-gateway project.
- BSTS/Lexicon availability shaped both VistA and RPMS search plans.
- CPRS diagnosis picker work could use a service boundary instead of embedding
  all terminology logic in the UI.

### 12. Clinical Fixtures Need To Be Documented And Reused

Date/time: May 27, 2026 3:59-4:10 PM UTC-4

Key wording: provide 12 standard clinical test cases, then "document these as
test cases"

Why it mattered: it converted demos into repeatable clinical validation.

Implications:

- Diagnosis/writeback work gained a reusable fixture set.
- Later AI Consult and CDS testing used the same clinical scenarios.
- Test coverage became clinically meaningful instead of purely route-level.

### 13. AI Consult Boundary Changed From Advisory-Only To Filed Reports

Date/time: Jun 4, 2026 3:44 PM and 4:17 PM UTC-4

Key wording:

- output should be FHIR bundle and "will not automatically update the patient's
  medical record"
- later: "diagnostic reports should be filed" and add `/aiconsult?dfn=`

Why it mattered: it introduced a safety boundary first, then deliberately
expanded it to provider-reviewed filing.

Implications:

- CDS output remained a FHIR bundle.
- `DiagnosticReport` became the right resource for AI Consult evidence.
- Filing moved behind an explicit workflow/service path rather than automatic
  background mutation.

### 14. DiagnosticReport Must Not Be Treated As A Note

Date/time: Jun 4-5, 2026 UTC-4

Key wording:

- "the resourceType should be DiagnosticReport"
- "should not have an encounter pointer"
- "diagnosticReports are still being mistaken for encounter notes"

Why it mattered: it corrected a resource identity error that could have polluted
the clinical note workflow.

Implications:

- Browser/export/import code had to preserve `DiagnosticReport` semantics.
- AI Consult evidence is not the same as `DocumentReference` or an Encounter
  note.
- Filing and display paths had to avoid reclassifying reports as notes.

### 15. Stage 2 CDS Should Be Isolated And Switchable

Date/time: Jun 2026

Key wording: Stage 2 should be a sibling service, with Stage 1 preserved as a
deployable rollback target.

Why it mattered: it kept the CDS work from turning into an in-place rewrite.

Implications:

- Stage 1 deterministic behavior remains a stable baseline.
- Stage 2 can add structured evidence and CDS Hooks compatibility separately.
- Deployment docs need explicit switch and rollback mechanics.

### 16. Use Existing C0FHIR Service Paths Instead Of Parallel Bundle Assembly

Date/time: Jun 8, 2026 5:36-5:45 PM UTC-4

Key wording:

- "have you written code to form a bundle from the graph instead of pulling the
  bundle from the C0FHIR... server?"
- "lets teach C0FHIR to emit LOINC codes where known"

Why it mattered: it redirected evidence assembly back to the service that owns
FHIR output.

Implications:

- `/fhir` and `/aiconsult` became the preferred bundle sources.
- Graph-only bundle construction became suspect unless it matched C0FHIR.
- Observation/vital code quality had to improve at the C0FHIR read layer.

### 17. After Vitals, Analyze Problems, Then Pick Easy Domains

Date/time: Jun 22, 2026 8:51 PM UTC-4 and surrounding RPMS work

Key wording:

- "next step is to analyze problems. first see how they were done there"
- "cool!! what else wil be easy to do?"

Why it mattered: it turned the RPMS rebuild track into a domain-by-domain
evidence loop.

Implications:

- Problems were inspected against RPMS reference behavior.
- Immunizations were tried because they could use existing PCE behavior.
- Allergies became next because `C0FWALG` was clearly a placeholder and RPMS uses
  a standard allergy package API.

## Summary

The strongest through-line is that the user repeatedly pushed the project away
from expedient shims and toward Codex-owned, RPMS-validated, UI-visible behavior.
The most consequential corrections were not just implementation details; they
set the operating rules: current C0FW/C0FHIR first, package APIs where correct,
RPMS-native stores where required, no dual write to hide uncertainty, and CPRS
as the proof surface.
