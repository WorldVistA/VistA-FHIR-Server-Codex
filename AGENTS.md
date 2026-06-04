# Agent Working Agreement

## Working principles

1. Don’t assume. Don’t hide confusion. Surface tradeoffs.
2. Minimum code that solves the problem. Nothing speculative.
3. Touch only what you must. Clean up only your own mess.
4. Define success criteria. Loop until verified.

Shared context source (primary):

- `https://github.com/glilly/ai-m/blob/master/agent-context/README.md`
- `https://github.com/glilly/ai-m/blob/master/agent-context/workflow.md`
- `https://github.com/glilly/ai-m/blob/master/agent-context/commands-template.md`
- `https://github.com/glilly/ai-m/blob/master/agent-context/security.md`
- `https://github.com/glilly/ai-m/blob/master/agent-context/checklist.md`
- `https://github.com/glilly/ai-m/blob/master/agent-context/vista-container-developer-guide.md`

Shared context source (local clone equivalent):

- `/home/glilly/ai-m/agent-context/README.md`
- `/home/glilly/ai-m/agent-context/workflow.md`
- `/home/glilly/ai-m/agent-context/commands-template.md`
- `/home/glilly/ai-m/agent-context/security.md`
- `/home/glilly/ai-m/agent-context/checklist.md`
- `/home/glilly/ai-m/agent-context/vista-container-developer-guide.md`

Repo-specific overrides:

- **TJSON maintainer repo:** `~/work/vista-stack/tjson-tooling` → `~/tjson-tooling` (`glilly/tjson-tools`): `%wd` / `%wdgraph`, Rust CLI notes, incoming automation. **FHIR browser WASM** for `/fhir?view=browser` is vendored in **this** repo under **`vendor/tjson/`** (see **`docs/FHIR_BROWSER_TJSON_CODEX.md`**).
- Keep repo-specific command/path details in local docs as needed.
- If there is a conflict, this repo's explicit instructions take precedence.
- **TIU / visit-linked note development:** use Docker **`vehu10`** as the patient source (VEHU DB). HTTP `http://127.0.0.1:9085/`, M user **`vehu`**, routines **`/home/vehu/p`**. Run **`./scripts/vehu10-fhir-sync.sh [dfn]`** to copy Codex `src/*.m`, register routes, and smoke **`/tiustats`**. The minimal **`fhir`** container (`9081`, `osehra`, `/home/osehra/p`) is fine for light smoke tests but often has **no** visit-linked TIU.
- **Exact phrases: "start the UI gateway server to vehu10" or "start the FHIR UI gateway server to vehu10"** mean the user demos from the backend-generated FHIR patient index at `http://localhost:5177/fhir`, then clicks the `rehmp` link in that table to open the CPRS demo for that patient.
  - Current demo package: `/home/glilly/work/vista-stack/rehmp/ehmp-ui/rehmp-cprs-demo`
  - Command: `./scripts/start-vehu10-fhir-gateway.sh`
  - The script starts a small gateway on port `5177`, proxies `/fhir` and backend paths to `vehu10` (`http://127.0.0.1:9085`), and serves the active CPRS demo behind `/demos/cprs/`.
  - User URL: `http://localhost:5177/fhir`
  - Expected proxy: `/fhir` -> `http://127.0.0.1:9085/fhir`
  - Health check: `curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5177/fhir/metadata` should return `200`.
  - Flow check: `curl -sS http://127.0.0.1:5177/fhir` should contain `/demos/cprs` and `rehmp`; one of those links should return `200` through `5177`.
  - Do not start archived `rehmp-fhir-demo` or `rehmp-rpc-demo`; they are not current. Do not treat `http://localhost:5177/demos/fhir/` as the demo entry point for this request; `/fhir` is the entry point.
- Current test SSH target: `osehra@127.0.0.1:2223`
- Current test SSH key: `/home/glilly/.ssh/id_ed25519_cursor_agent_test`
- Agent note: a full SSH session to this target often takes **40+ seconds**; the default agent command wait is **30s**, so SSH can be backgrounded and look “stuck” before it finishes. Use **`block_until_ms` ≥ 60000** (or read the terminal file after backgrounding) and request **`network`** permission when running SSH from the agent.
- The `127.0.0.1:2223` SSH target is **local test access only**. Do **not** use port `2223` for public hosts. For remote Codex deploys, use the documented remote paths first: `scripts/fhirdev-codex-sync.sh` defaults to `root@devfhir.vistaplex.org` / container `fhirdev22`; production is `root@fhir.vistaplex.org` / container `fhir` unless `docker ps` on that host says otherwise.
- Current test routine directory: `/home/osehra/p`
- After **`docker restart`** of the test container: restart the M web listener before HTTP smoke tests — see **`~/ops/agent-context/vista-container-developer-guide.md`** §10 (**`stop^%webreq`** / **`go^%webreq`**, **`^%webhttp`** check).

Required gate before commit:

1. Copy changed code to test server.
2. Reload routines/services as required.
3. Run `XINDEX` on changed routines.
4. Run smoke tests for changed behavior.
5. Commit only when all checks pass.
