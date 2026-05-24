# agent-hub-roles

**Persona-layer doc-only monorepo** for [agent-hub](https://github.com/kishibashi3/agent-hub).

Each role — reviewer / planner / researcher / writer-ja / writer-en / operator — ships a persona doc and workspace template in one repo. Use this as a **GitHub Template Repository**: fork it, run it, and accumulate your own operational knowledge on top.

## Fork model

```
agent-hub-roles (upstream template, this repo)
    │
    │ "Use this template" or fork
    ▼
my-agent-hub-roles (your operational workspace)
    ├── per-role CLAUDE.md (from upstream)
    └── feedback-archive/ / planning-archive/ / research-archive/ (grows with your usage)
```

### How to use

1. **Fork** (recommended: "Use this template" button)
   - From this repo's GitHub page: "Use this template" → "Create a new repository"
   - Or: `gh repo create my-agent-hub-roles --template kishibashi3/agent-hub-roles --private`
2. **Run from your fork** — your `feedback-archive`, `planning-archive`, etc. grow over time
3. **Contribute learnings back upstream** via PR when you have something generally useful

Upstream provides ecosystem-wide conventions (`CLAUDE.md`: terminology / L0-L2 / register / archive) and base persona docs for each role. Your private fork layers your own operational logs on top.

## Roles

| Role | Description | Live workspace (operator sample) |
|---|---|---|
| **reviewer** | PR / diff / file review, `@reviewer` peer | [`private/agent-hub-reviewer`](https://github.com/kishibashi3/agent-hub-reviewer) |
| **planner** | Planning / task assignment / merge decisions, `@planner` peer | [`private/agent-hub-planner`](https://github.com/kishibashi3/agent-hub-planner) |
| **researcher** | Issue investigation / summarization, `@researcher` peer | [`private/agent-hub-researcher`](https://github.com/kishibashi3/agent-hub-researcher) |
| **writer-ja** | Japanese writing (note series / docs), `@writer-ja` peer | `writer-ja/` (in this monorepo) |
| **writer-en** | English writing (Dev.to / docs), `@writer-en` peer | `writer-en/` (in this monorepo) |
| **operator** | Bridge lifecycle + inventory (human Claude Code session, not a bridge) | `operator/` |

> **writer-ja / writer-en** migrated into this monorepo in M5 (2026-05-21). The former `agent-hub-bridge-writer` and `agent-hub-bridge-writer-en` repos are archived.
> Other roles (reviewer / planner / researcher) continue running from their per-role repos; monorepo migration is planned for a future milestone.

## Quick start

### Prerequisites (one-time install)

> ⚠️ **`scripts/start.sh` requires bash 4+** (uses associative arrays). macOS ships `/bin/bash` 3.2, so macOS users need `brew install bash`. On Apple Silicon run `/opt/homebrew/bin/bash scripts/start.sh ...`; on Intel Mac `/usr/local/bin/bash scripts/start.sh ...`. Linux ships bash 4+ and works as-is.

```bash
# 1. Verify bash 4+ (required on macOS, usually fine on Linux)
bash --version    # → GNU bash, version 4.x or 5.x ...

# 2. Install agent-hub-bridges[claude] (provides the bridge spawn command)
pip install "agent-hub-bridges[claude] @ git+https://github.com/kishibashi3/agent-hub-bridges.git"

# 3. Export env vars (add to ~/.bashrc / ~/.zshrc)
export AGENT_HUB_URL="https://your-agent-hub.example.com/mcp"
export AGENT_HUB_USER="operator"      # register this Claude Code session as @operator
export GITHUB_PAT="ghp_..."           # read:user scope
export AGENT_HUB_TENANT="your-tenant" # optional

# 4. (Optional) copy and edit scripts/operator-env.sh.example, then source it
```

### Start bridges

```bash
cd <your-agent-hub-roles-fork>

./scripts/start.sh                         # operator only (default — launches Claude Code)
./scripts/start.sh all                     # spawn all 4 role bridges in background + open operator
./scripts/start.sh reviewer planner        # spawn specific roles
./scripts/start.sh --help                  # show usage
```

Each role runs as a persona layer on top of [`agent-hub-bridges[claude]`](https://github.com/kishibashi3/agent-hub-bridges):
- **reviewer / planner / researcher / writer-ja / writer-en**: `agent-hub-bridge-claude --user <role>` spawned as a separate background process
- **operator**: `claude` (Claude Code itself, connecting as `@operator` via the agent-hub-plugin)

Operator setup details: [`operator/CLAUDE.md`](./operator/CLAUDE.md).

## Structure

```
agent-hub-roles/
├── CLAUDE.md                 # Shared conventions (terminology / L0-L2 / register / archive)
├── README.md                 # This file
├── CHANGELOG.md              # M0+ changelog
├── reviewer/
│   ├── CLAUDE.md             # Reviewer persona
│   ├── REVIEW_TEMPLATE.md
│   ├── REVIEW_CRITERIA.md
│   ├── REVIEW_FRAMEWORK.md
│   └── feedback-archive/.gitkeep
├── planner/
│   ├── CLAUDE.md
│   └── planning-archive/.gitkeep
├── researcher/
│   ├── CLAUDE.md
│   ├── RESEARCH_TEMPLATE.md
│   └── research-archive/.gitkeep
├── writer-ja/
│   └── CLAUDE.md
├── writer-en/
│   └── CLAUDE.md
├── operator/
│   └── CLAUDE.md
├── scripts/
│   ├── start.sh              # Role launch wrapper (operator default / all / role-list)
│   └── operator-env.sh.example  # Operator env template (copy, edit, source)
└── .github/workflows/ci.yml
```

## Sibling repos (ecosystem)

| Repo | Role |
|---|---|
| [agent-hub](https://github.com/kishibashi3/agent-hub) | Server (TypeScript + SQLite + MCP) |
| [agent-hub-bridges](https://github.com/kishibashi3/agent-hub-bridges) | Engine layer monorepo (Claude / Slack / Gemini / A2A) |
| [agent-hub-sdk](https://github.com/kishibashi3/agent-hub-sdk) | Python client SDK |
| **agent-hub-roles** (this repo) | **Persona layer monorepo** |

## Development (contributing upstream)

```bash
git clone git@github.com:kishibashi3/agent-hub-roles.git
cd agent-hub-roles

# Markdown link check (same as CI)
# See .github/workflows/ci.yml for the local check command
```

## License

Apache-2.0

## Related issues

- Epic: [#1](https://github.com/kishibashi3/agent-hub-roles/issues/1)
- M0: [#4](https://github.com/kishibashi3/agent-hub-roles/issues/4)
