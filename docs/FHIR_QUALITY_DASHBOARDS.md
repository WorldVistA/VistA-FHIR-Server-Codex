# FHIR Quality Dashboards

Routes (Codex M HTML):

| URL | Purpose |
|-----|---------|
| `GET /fhir-quality-dashboards` | Summary of **active** measures (+ aggregate IPP/DENOM/NUMER) |
| `GET /fhir-quality-dashboards/{measure}` | Single-measure dashboard |
| `GET /fhir-quality-dashboards?measure=CMS165v14` | Same as path form |
| `GET /fhir-quality-dashboards?view=all` | Full catalog (active + inactive) |
| `GET /fhir-quality-dashboard` | Legacy alias → active summary |

## Single-measure page contents

1. **Status / calc mode / measurement period / FHIR focus**
2. **Brief IPP criteria**
3. **Current summary results** — IPP / DENOM / NUMER / DENEX / rate (from curated CQL cohort when available)
4. **Measure calculation** — CQM tool versions + link to calculation docs
5. **Patient table** — IPP / DENOM / NUMER / DENEX / evidence, FHIR browser (live + source bundle), rehmp, AI Consult, altfhir bundle

Per-DFN population flags are optional until stored:

```m
D SETPOP^C0FQUAL("CMS165v14",101090,1,1,1,0,"HTN+BP controlled","official-cql")
```

## Globals (`^C0FQUAL`)

| Node | Meaning |
|------|---------|
| `MEAS,CMS` | `TITLE^FOCUS^STATUS^NOTE` (`A`/`I`) |
| `META,CMS` | `IPP^PERIOD^DOCS^TOOLS^MODE` |
| `SUM,CMS` | `N^IPP^DENOM^NUMER^DENEX^ASOF^COHORT` |
| `POP,CMS,DFN` | `IPP^DENOM^NUMER^DENEX^EVIDENCE^MODE` |

Seed version `^C0FQUAL(0)=3` refreshes CMS165/CMS122 aggregate cards from the 2026-07-24 overnight CQL re-eval (preserves Active flags).

Default active: `CMS165v14`, `CMS122v14`.

```m
D ACTIVATE^C0FQUAL("CMS130v14")
D DEACTIVATE^C0FQUAL("CMS122v14")
```

## Seeded summary (selected-18 CQL, 2026-07-24)

| Measure | IPP / DENOM / NUMER | Mode |
|---------|---------------------:|------|
| CMS165v14 | **14 / 14 / 14** (n=18) | official-cql |
| CMS122v14 | **5 / 5 / 0** (n=18) | official-cql |

Source batches: `HL7-FHIR-quality-testing/2026/cohorts/*/reports/cqm-execution-batch.json`.

Graph DFN rows show **—** until `SETPOP` is used; aggregate card is the official CQL summary.

## Smoke

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9085/fhir-quality-dashboards
curl -sS http://127.0.0.1:9085/fhir-quality-dashboards/CMS165v14 | tr '>' '>\n' | rg -n 'Initial Population|summary results|CQM tools|rehmp|IPP|NUMER' | head
```
