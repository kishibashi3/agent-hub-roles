#!/usr/bin/env bash
# new-role.sh — Create a new role: GitHub repo + CLAUDE.md + bridge spawn
#
# Usage:
#   new-role.sh --from <role-template> --name <handle> --workdir <path> --repos <repo-name>
#               [--model bridge-claude] [--tenant <tenant>] [--public] [--display-name "..."]
#               [--no-repo] [--no-spawn] [--dry-run]
#
# Flags:
#   --from <role>        Role template to copy CLAUDE.md from (required)
#   --name <handle>      Bridge handle (@name) (required)
#   --workdir <path>     Working directory for the new role (required)
#   --repos <repo-name>  GitHub repo name (required unless --no-repo)
#   --model <bridge>     Bridge binary alias (default: bridge-claude)
#   --tenant <tenant>    agent-hub tenant name
#   --public             Create public GitHub repo (default: private)
#   --display-name "..." Bridge display name passed to --display-name
#   --no-repo            Skip GitHub repo create/clone; copy CLAUDE.md into
#                        --workdir directly and commit to the existing git repo
#   --no-spawn           Skip bridge spawn after setup
#   --dry-run            Print what would happen without making changes
#
# Required env:
#   AGENT_HUB_ROLES  — path to the agent-hub-roles repo root
#   AGENT_HUB_URL    — agent-hub server URL
#   GITHUB_PAT       — GitHub personal access token
#
# Examples:
#   # Standalone repo (classic):
#   new-role.sh --from coder --name coder --workdir $AGENT_HUB_BASE/coder --repos coder
#
#   # Add to existing monorepo (--no-repo):
#   new-role.sh --from coder --name philosopher --workdir $AGENT_HUB_ROLES/philosopher --no-repo

set -euo pipefail

# ---------- defaults ----------
MODEL="bridge-claude"
TENANT=""
PUBLIC=false
DISPLAY_NAME=""
DRY_RUN=false
NO_REPO=false
NO_SPAWN=false
REPOS=""
SPAWN_TIMEOUT=30

# ---------- bridge binary map ----------
declare -A BRIDGE_BINARIES=(
    [bridge-claude]="agent-hub-bridge-claude"
    [bridge-gemini]="agent-hub-bridge-gemini"
    [bridge-claude-p]="agent-hub-bridge-claude-p"
)

# ---------- parse args ----------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)         FROM_NAME="$2"; shift 2 ;;
        --name)         NAME="$2"; shift 2 ;;
        --workdir)      WORKDIR="$2"; shift 2 ;;
        --repos)        REPOS="$2"; shift 2 ;;
        --model)        MODEL="$2"; shift 2 ;;
        --tenant)       TENANT="$2"; shift 2 ;;
        --public)       PUBLIC=true; shift ;;
        --display-name) DISPLAY_NAME="$2"; shift 2 ;;
        --no-repo)      NO_REPO=true; shift ;;
        --no-spawn)     NO_SPAWN=true; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        -h|--help)
            sed -n '2,29p' "$0" | sed 's/^# *//'
            exit 0 ;;
        *) echo "error: unknown flag: $1" >&2; exit 2 ;;
    esac
done

# ---------- validate required ----------
: "${FROM_NAME:?--from is required}"
: "${NAME:?--name is required}"
: "${WORKDIR:?--workdir is required}"
: "${AGENT_HUB_ROLES:?AGENT_HUB_ROLES env is not set}"

if [[ "$NO_REPO" == false ]]; then
    : "${REPOS:?--repos is required (or pass --no-repo to skip repo creation)}"
fi

# ---------- name validation (path traversal guard) ----------
if ! [[ "$NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    echo "error: --name must match [a-z0-9][a-z0-9_-]* (got: '$NAME')" >&2
    exit 2
fi
if ! [[ "$FROM_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    echo "error: --from must match [a-z0-9][a-z0-9_-]* (got: '$FROM_NAME')" >&2
    exit 2
fi

# ---------- resolve paths ----------
ROLES_ROOT="$(realpath "$AGENT_HUB_ROLES")"
SRC_CLAUDE="$ROLES_ROOT/$FROM_NAME/CLAUDE.md"
WORKDIR="$(realpath -m "$WORKDIR")"  # -m: allow non-existent

# security: src must stay within ROLES_ROOT
case "$SRC_CLAUDE" in
    "$ROLES_ROOT"/*) ;;
    *) echo "error: resolved path escapes AGENT_HUB_ROLES: $SRC_CLAUDE" >&2; exit 2 ;;
esac

# workdir basename must match repos (only when --no-repo is not set)
if [[ "$NO_REPO" == false ]]; then
    if [[ "$(basename "$WORKDIR")" != "$REPOS" ]]; then
        echo "error: --workdir basename ('$(basename "$WORKDIR")') must match --repos ('$REPOS')" >&2
        echo "       set --workdir to $(dirname "$WORKDIR")/$REPOS" >&2
        exit 2
    fi
fi

# bridge binary must exist (skip when --no-spawn)
if [[ "$NO_SPAWN" == false ]]; then
    BRIDGE_BIN="${BRIDGE_BINARIES[$MODEL]:-}"
    if [[ -z "$BRIDGE_BIN" ]]; then
        echo "error: unknown --model '$MODEL'. Valid: ${!BRIDGE_BINARIES[*]}" >&2
        exit 2
    fi
    if ! command -v "$BRIDGE_BIN" &>/dev/null; then
        echo "error: binary not found: $BRIDGE_BIN. Is agent-hub-bridges installed?" >&2
        exit 2
    fi
fi

# ---------- dry-run checks ----------
ISSUES=()

[[ ! -f "$SRC_CLAUDE" ]] && ISSUES+=("FAIL  --from: CLAUDE.md not found: $SRC_CLAUDE")
[[ -f "$SRC_CLAUDE" ]]   && ISSUES+=("OK    --from: $SRC_CLAUDE")

if [[ -d "$WORKDIR" ]] && [[ -n "$(ls -A "$WORKDIR" 2>/dev/null)" ]]; then
    ISSUES+=("FAIL  --workdir: already exists and is non-empty: $WORKDIR")
else
    ISSUES+=("OK    --workdir: $WORKDIR (will be created)")
fi

if [[ "$NO_REPO" == true ]]; then
    ISSUES+=("OK    --no-repo: skipping GitHub repo create/clone")
    # verify workdir is inside an existing git repo
    if ! git -C "$(dirname "$WORKDIR")" rev-parse --git-dir &>/dev/null 2>&1; then
        ISSUES+=("WARN  --no-repo: parent of --workdir does not appear to be inside a git repo")
    fi
else
    if gh repo view "$REPOS" &>/dev/null 2>&1; then
        ISSUES+=("WARN  --repos: repo already exists on GitHub (will clone existing)")
    else
        ISSUES+=("OK    --repos: will create $REPOS")
    fi
fi

if [[ "$NO_SPAWN" == true ]]; then
    ISSUES+=("OK    --no-spawn: skipping bridge spawn")
else
    [[ -z "${AGENT_HUB_URL:-}" ]] && ISSUES+=("WARN  AGENT_HUB_URL: not set")
    [[ -z "${GITHUB_PAT:-}" ]]    && ISSUES+=("WARN  GITHUB_PAT: not set")
fi

echo "=== dry-run checks ==="
for line in "${ISSUES[@]}"; do
    echo "  $line"
done

if printf '%s\n' "${ISSUES[@]}" | grep -q '^FAIL'; then
    echo "=> FAILED: fix issues above before running" >&2
    exit 1
fi
echo "=> OK: all checks passed"

[[ "$DRY_RUN" == true ]] && exit 0

# ---------- actual execution ----------

# 1. create workdir if needed
mkdir -p "$WORKDIR"

if [[ "$NO_REPO" == false ]]; then
    # 2. create or clone repo
    if gh repo view "$REPOS" &>/dev/null 2>&1; then
        echo "==> repo '$REPOS' already exists, cloning..."
        gh repo clone "$REPOS" "$WORKDIR"
    else
        echo "==> creating repo '$REPOS'..."
        VISIBILITY_FLAG="--private"
        [[ "$PUBLIC" == true ]] && VISIBILITY_FLAG="--public"
        gh repo create "$REPOS" "$VISIBILITY_FLAG" --clone --gitignore "" 2>/dev/null || \
            gh repo create "$REPOS" "$VISIBILITY_FLAG" --clone
        # gh repo create --clone creates in cwd/<repos>/
        # move to workdir if different
        CLONED_DIR="$(pwd)/$REPOS"
        if [[ "$CLONED_DIR" != "$WORKDIR" ]]; then
            mv "$CLONED_DIR" "$WORKDIR"
        fi
    fi
fi

# 3. copy CLAUDE.md
echo "==> copying CLAUDE.md from $FROM_NAME..."
cp "$SRC_CLAUDE" "$WORKDIR/CLAUDE.md"

# 4. rewrite self-awareness (handle + workdir)
echo "==> rewriting self-awareness section..."
sed -i "s|- \*\*handle\*\*: \`.*\`|- **handle**: \`@${NAME}\`|" "$WORKDIR/CLAUDE.md"
sed -i "s|- \*\*workdir\*\*: \`.*\`|- **workdir**: \`${WORKDIR}/\`|" "$WORKDIR/CLAUDE.md"

# 5. git commit + push
echo "==> committing and pushing..."
git -C "$WORKDIR" add CLAUDE.md
git -C "$WORKDIR" commit -m "add: ${FROM_NAME} CLAUDE.md (new-role: @${NAME})"
git -C "$WORKDIR" push origin main

# 6. spawn bridge (skip if --no-spawn)
if [[ "$NO_SPAWN" == true ]]; then
    echo "==> --no-spawn: skipping bridge spawn. Setup complete."
    exit 0
fi

LOG="/tmp/bridge-${NAME}.log"
echo "" > "$LOG"

CMD=("$BRIDGE_BIN" "--user" "$NAME" "--workdir" "$WORKDIR")
[[ -n "$TENANT" ]]       && CMD+=("--tenant" "$TENANT")
[[ -n "$DISPLAY_NAME" ]] && CMD+=("--display-name" "$DISPLAY_NAME")

echo "==> spawning bridge @${NAME}... (log: $LOG)"
"${CMD[@]}" >> "$LOG" 2>&1 &
disown

# 7. wait for "listening on inbox"
DEADLINE=$(( $(date +%s) + SPAWN_TIMEOUT ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
    if grep -q "listening on inbox" "$LOG" 2>/dev/null; then
        echo "==> bridge @${NAME} is ready. log: $LOG"
        exit 0
    fi
    sleep 0.5
done

echo "error: bridge @${NAME} did not reach 'listening on inbox' within ${SPAWN_TIMEOUT}s. Check: $LOG" >&2
exit 1
