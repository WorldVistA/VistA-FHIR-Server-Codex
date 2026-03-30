# Agent Working Agreement

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

- Keep repo-specific command/path details in local docs as needed.
- If there is a conflict, this repo's explicit instructions take precedence.
- **TIU / visit-linked note development:** use Docker **`vehu10`** as the patient source (VEHU DB). HTTP `http://127.0.0.1:9085/`, M user **`vehu`**, routines **`/home/vehu/p`**. Run **`./scripts/vehu10-fhir-sync.sh [dfn]`** to copy Codex `src/*.m`, register routes, and smoke **`/tiustats`**. The minimal **`fhir`** container (`9081`, `osehra`, `/home/osehra/p`) is fine for light smoke tests but often has **no** visit-linked TIU.
- Current test SSH target: `osehra@127.0.0.1:2223`
- Current test SSH key: `/home/glilly/.ssh/id_ed25519_cursor_agent_test`
- Agent note: a full SSH session to this target often takes **40+ seconds**; the default agent command wait is **30s**, so SSH can be backgrounded and look “stuck” before it finishes. Use **`block_until_ms` ≥ 60000** (or read the terminal file after backgrounding) and request **`network`** permission when running SSH from the agent.
- Current test routine directory: `/home/osehra/p`
- After **`docker restart`** of the test container: restart the M web listener before HTTP smoke tests — see **`~/ops/agent-context/vista-container-developer-guide.md`** §10 (**`stop^%webreq`** / **`go^%webreq`**, **`^%webhttp`** check).

Required gate before commit:

1. Copy changed code to test server.
2. Reload routines/services as required.
3. Run `XINDEX` on changed routines.
4. Run smoke tests for changed behavior.
5. Commit only when all checks pass.
