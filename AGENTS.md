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
- Current test SSH target: `osehra@127.0.0.1:2223`
- Current test SSH key: `/home/glilly/.ssh/id_ed25519_cursor_agent_test`
- Current test routine directory: `/home/osehra/p`

Required gate before commit:

1. Copy changed code to test server.
2. Reload routines/services as required.
3. Run `XINDEX` on changed routines.
4. Run smoke tests for changed behavior.
5. Commit only when all checks pass.
