# FHIR Quality Dashboards

Routes (Codex M HTML):

| URL | Purpose |
|-----|---------|
| `GET /fhir-quality-dashboards` | Summary of **active** measures |
| `GET /fhir-quality-dashboards/{measure}` | Single-measure dashboard |
| `GET /fhir-quality-dashboards?measure=CMS165v14` | Same as path form |
| `GET /fhir-quality-dashboards?view=all` | Full catalog (active + inactive) |
| `GET /fhir-quality-dashboard` | Legacy alias → active summary |

## Active measures

Stored in `^C0FQUAL("MEAS",CMSID)=TITLE^FOCUS^STATUS^NOTE` with `STATUS` `A` or `I`.

Seeded on `EN^SYNWEBRG` / first dashboard hit (`SEED^C0FQUAL`):

- **Active by default:** `CMS165v14`, `CMS122v14` (matches rehmp Quality AI Consult)
- **Catalog inactive:** CMS130, CMS125, CMS22, CMS2, CMS68, CMS138, CMS131

```m
D ACTIVATE^C0FQUAL("CMS130v14")
D DEACTIVATE^C0FQUAL("CMS122v14")
```

## Implementation

- `src/C0FQUAL.m` — catalog + HTML
- `QDASHES^C0FHIRWS` — web entry
- `SYNWEBRG` — route registration
- Gateway (`start-vehu10-fhir-gateway.sh`) proxies `/fhir-quality-dashboards*` to the FHIR backend

## Smoke

```bash
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9085/fhir-quality-dashboards
curl -sS http://127.0.0.1:9085/fhir-quality-dashboards | head
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9085/fhir-quality-dashboards/CMS165v14
```
