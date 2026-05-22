#!/usr/bin/env bash
#
# start.sh — spawn agent-hub role workers from this workspace.
#
# Usage:
#   scripts/start.sh                          # operator only (= guidance, no spawn)
#   scripts/start.sh all                      # operator guidance + spawn 4 role bridges
#   scripts/start.sh reviewer                 # spawn a single role bridge
#   scripts/start.sh reviewer planner         # spawn multiple role bridges
#
# Roles:
#   operator                                  # Claude Code session (= you), not a bridge
#   reviewer / planner / researcher / writer  # agent-hub-bridge-claude subprocess
#
# Behavior:
#   - operator branch prints how to register this Claude Code session as @operator
#     via the agent-hub-plugin (env vars + plugin install). It does NOT spawn
#     anything. See operator/CLAUDE.md for the canonical setup doc.
#   - Bridge roles are spawned with:
#       agent-hub-bridge-claude --user <role> --workdir <repo-root>/<role>/
#     logs go to /tmp/agent-hub-bridge-<role>.log.
#   - AGENT_HUB_TENANT is read from env (no flag, no hard-code). Unset → warning.
#   - AGENT_HUB_URL is healthchecked with curl; failure → warning, but we still
#     start (= server may be coming up; bridge will retry).
#
# Prereqs (= installed beforehand; see README):
#   - agent-hub-bridges[claude]  (provides `agent-hub-bridge-claude` on PATH)
#   - agent-hub-plugin           (for operator role, optional for bridge-only runs)
#   - agent-hub-sdk              (transitive dep of bridges)

set -euo pipefail

# ----- bash version guard --------------------------------------------------
# This script uses `declare -A` (associative arrays), introduced in bash 4.0
# (2009). macOS's bundled /bin/bash is stuck on 3.2.x for licensing reasons,
# so we fail fast with an actionable error rather than crashing mid-run with
# a cryptic "declare: -A: invalid option" message. See agent-hub-roles#8.
if (( BASH_VERSINFO[0] < 4 )); then
  printf 'error: bash >= 4.0 required (running %s)\n' "${BASH_VERSION:-unknown}" >&2
  printf '  macOS users: brew install bash, then re-run with the Homebrew bash:\n' >&2
  printf '    Apple Silicon: /opt/homebrew/bin/bash %s\n' "$0" >&2
  printf '    Intel Mac:     /usr/local/bin/bash %s\n' "$0" >&2
  printf '  Linux users: most distros already ship bash 4+; check with `bash --version`.\n' >&2
  exit 3
fi

# Resolve repo root regardless of where the script is invoked from. We assume
# this file lives at <repo-root>/scripts/start.sh; bridge --workdir paths and
# operator guidance both anchor on this directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Each role name = its subdirectory name = its agent-hub handle.
BRIDGE_ROLES=(reviewer planner researcher writer-ja writer-en knowledge deep-research)
ALL_ROLES=(operator "${BRIDGE_ROLES[@]}")

# ----- ANSI colors (fall back to no-color on dumb terminals) ----------------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
  C_BOLD="$(tput bold)"
  C_GREEN="$(tput setaf 2)"
  C_YELLOW="$(tput setaf 3)"
  C_RED="$(tput setaf 1)"
  C_DIM="$(tput dim)"
  C_RESET="$(tput sgr0)"
else
  C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_RESET=""
fi

info()  { printf '%s[info]%s %s\n'  "${C_GREEN}"  "${C_RESET}" "$*" ; }
warn()  { printf '%s[warn]%s %s\n'  "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
error() { printf '%s[error]%s %s\n' "${C_RED}"    "${C_RESET}" "$*" >&2; }
dim()   { printf '%s%s%s\n'         "${C_DIM}"    "$*"          "${C_RESET}"; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

print_usage() {
  cat <<EOF
Usage:
  $(basename "$0")                                # operator guidance only (default)
  $(basename "$0") all                            # operator + all 4 bridge roles
  $(basename "$0") <role>...                      # specific role(s)

Roles: ${ALL_ROLES[*]}

Examples:
  $(basename "$0")                  # show how to start your Claude Code as @operator
  $(basename "$0") all              # spawn reviewer/planner/researcher/writer bridges
  $(basename "$0") reviewer         # spawn only the reviewer bridge

See README.md for prereqs and operator/CLAUDE.md for the full operator setup.
EOF
}

# Build the list of roles to act on. Default = ["operator"] (= guidance only).
# "all" expands to the operator guidance + every bridge role.
if [[ $# -eq 0 ]]; then
  REQUESTED_ROLES=(operator)
elif [[ $# -eq 1 && "$1" == "all" ]]; then
  REQUESTED_ROLES=(operator "${BRIDGE_ROLES[@]}")
elif [[ $# -eq 1 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
  print_usage
  exit 0
else
  REQUESTED_ROLES=("$@")
fi

# Validate every requested role up front; we'd rather fail before spawning
# anything than partially launch and then bail out mid-flight.
for role in "${REQUESTED_ROLES[@]}"; do
  found=0
  for known in "${ALL_ROLES[@]}"; do
    [[ "$role" == "$known" ]] && { found=1; break; }
  done
  if [[ $found -eq 0 ]]; then
    error "unknown role: $role (expected one of: ${ALL_ROLES[*]} or 'all')"
    print_usage >&2
    exit 2
  fi
done

# ---------------------------------------------------------------------------
# Environment checks (best-effort warnings, not fatal)
# ---------------------------------------------------------------------------

check_env_and_server() {
  # Tenant is per-fork-user setting; we warn rather than refuse because some
  # tenants have an empty/default value and the bridge itself accepts unset.
  if [[ -z "${AGENT_HUB_TENANT:-}" ]]; then
    warn "AGENT_HUB_TENANT is unset; bridges will join the default tenant."
    warn "Set it in your shell env (~/.bashrc / ~/.zshrc) if you want a specific tenant."
  else
    info "AGENT_HUB_TENANT=${AGENT_HUB_TENANT}"
  fi

  # Server healthcheck. We only WARN — start.sh does not own the server's
  # lifecycle (operator runs it separately). Bridges retry on their own.
  if [[ -z "${AGENT_HUB_URL:-}" ]]; then
    warn "AGENT_HUB_URL is unset; bridges will not be able to connect."
    warn "Set AGENT_HUB_URL (e.g. https://agent-hub.example.com/mcp) and retry."
    return 0
  fi
  info "AGENT_HUB_URL=${AGENT_HUB_URL}"

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not on PATH; skipping AGENT_HUB_URL healthcheck."
    return 0
  fi

  # We hit the MCP endpoint with a HEAD request, expecting any response (even
  # 401/404) — getting a TCP-level connect means the server is up. A timeout
  # or connect refusal is the actual "down" signal we warn about.
  if curl --silent --show-error --connect-timeout 3 --max-time 5 \
        --output /dev/null --head "${AGENT_HUB_URL}" 2>/dev/null; then
    info "agent-hub server healthcheck OK"
  else
    warn "agent-hub server at ${AGENT_HUB_URL} did not respond within 5s."
    warn "Bridges will start anyway and retry; start the server if you haven't yet."
  fi
}

# ---------------------------------------------------------------------------
# Per-role actions
# ---------------------------------------------------------------------------

handle_operator() {
  cat <<EOF

${C_BOLD}@operator setup${C_RESET} (= Claude Code session, not a bridge worker)

operator is the human-driven Claude Code session that bootstraps the ecosystem.
It is NOT spawned by this script. To register THIS shell's Claude Code as
@operator:

  1. Ensure your shell env exports:
       export AGENT_HUB_URL=https://<your-server>/mcp
       export GITHUB_PAT=ghp_...                # read:user scope
       export AGENT_HUB_USER=operator           # makes you @operator
       export AGENT_HUB_TENANT=<your-tenant>    # optional, joins default if unset

     You can copy scripts/operator-env.sh.example to ~/.agent-hub-operator.env
     and source it from ~/.bashrc.

  2. Install the agent-hub-plugin once (if not already):
       # inside Claude Code:
       /plugin marketplace add https://github.com/kishibashi3/kishibashi3-plugins-claude
       /plugin install agent-hub-plugin
       /reload-plugins

  3. Start Claude Code from the operator directory so operator/CLAUDE.md loads:
       cd ${REPO_ROOT}/operator
       claude

     The plugin's .mcp.json will pick up AGENT_HUB_USER=operator and register
     this session as @operator on the agent-hub server.

  4. Verify with /mcp inside Claude Code — should show agent-hub connected.

See operator/CLAUDE.md for the full setup walkthrough.
EOF
}

spawn_bridge() {
  local role="$1"
  local workdir="${REPO_ROOT}/${role}"
  local log="/tmp/agent-hub-bridge-${role}.log"

  if [[ ! -d "$workdir" ]]; then
    error "$role: workdir missing at $workdir (did the fork checkout complete?)"
    return 1
  fi

  if ! command -v agent-hub-bridge-claude >/dev/null 2>&1; then
    error "agent-hub-bridge-claude not on PATH"
    error "  install: pip install 'agent-hub-bridges[claude] @ git+https://github.com/kishibashi3/agent-hub-bridges.git'"
    return 1
  fi

  info "spawning @${role} bridge (workdir=${workdir}, log=${log})"
  # Background-launch the bridge. We deliberately do NOT keep a parent shell
  # holding the child — `disown` lets the bridge survive this script exiting.
  # Bridges manage their own reconnect / heartbeat against agent-hub.
  nohup agent-hub-bridge-claude \
    --user "$role" \
    --workdir "$workdir" \
    >"$log" 2>&1 &
  disown
  dim "  pid=$! (tail -f ${log} to follow)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

info "agent-hub-roles start.sh — repo root: ${REPO_ROOT}"
info "requested roles: ${REQUESTED_ROLES[*]}"

# Only run env / server checks if we're actually going to spawn a bridge or
# print operator setup (= every path needs them, but skip if --help slipped
# through). With the parser above, this is always reached.
check_env_and_server

# Process roles in declaration order so the operator guidance prints first
# (when "all" is requested), followed by bridge spawns. We dedupe to handle
# `start.sh reviewer reviewer` gracefully.
declare -A SEEN=()
for role in "${REQUESTED_ROLES[@]}"; do
  if [[ -n "${SEEN[$role]:-}" ]]; then
    continue
  fi
  SEEN[$role]=1

  if [[ "$role" == "operator" ]]; then
    handle_operator
  else
    spawn_bridge "$role"
  fi
done

info "done. Bridges (if any) are running in the background; use 'pgrep -fa agent-hub-bridge-claude' to inspect."
