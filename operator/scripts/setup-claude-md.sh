#!/usr/bin/env bash
#
# setup-claude-md.sh — link `$AGENT_HUB_ROOT/CLAUDE.md` → operation repo's canonical.
#
# Why this exists:
#
# `app/CLAUDE.md` is the ecosystem-wide CLAUDE doc that all peers / operator
# Claude Code sessions implicitly read. Because it lives at the *parent*
# directory of every git repo we work in, it doesn't belong to any single
# repo's history — it's drift-prone and any in-place edit can vanish
# when the host machine is reset. operator/CLAUDE.md (= operation repo)
# documents the inventory model; this script ties the actual `CLAUDE.md`
# file at `$AGENT_HUB_ROOT/CLAUDE.md` to the version-controlled canonical
# at `<operation-repo>/config/app-CLAUDE.md` via a symlink.
#
# Semantics:
#   - If $AGENT_HUB_ROOT is unset → abort (we don't guess where you keep your
#     ecosystem root; eventual installer (#101) will export it for you).
#   - If $AGENT_HUB_ROOT/CLAUDE.md is a regular file (not a symlink) → warn
#     and skip. The file may carry uncommitted edits we don't want to clobber;
#     the operator can `mv it config/app-CLAUDE.md` themselves to bless the
#     current content as the new canonical, then re-run this script.
#   - Otherwise (= symlink or absent) → `ln -sf` the canonical's absolute
#     path. Re-running is idempotent: an existing symlink pointing at the
#     same target stays a symlink at the same target.
#
# Usage:
#   export AGENT_HUB_ROOT=/home/<you>/app   # one-time, in ~/.bashrc
#   <operation-repo>/scripts/setup-claude-md.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
CANONICAL="$(cd "$CONFIG_DIR" && pwd)/app-CLAUDE.md"

if [[ -z "${AGENT_HUB_ROOT:-}" ]]; then
  printf 'error: AGENT_HUB_ROOT is not set.\n' >&2
  printf '  Add to your shell rc (one-time, see operation/CLAUDE.md § AGENT_HUB_ROOT):\n' >&2
  printf '    export AGENT_HUB_ROOT=/home/<you>/app\n' >&2
  printf '  Then re-run %s.\n' "$0" >&2
  exit 1
fi

if [[ ! -d "$AGENT_HUB_ROOT" ]]; then
  printf 'error: AGENT_HUB_ROOT=%s is not a directory.\n' "$AGENT_HUB_ROOT" >&2
  exit 1
fi

if [[ ! -f "$CANONICAL" ]]; then
  printf 'error: canonical file missing at %s\n' "$CANONICAL" >&2
  printf '  (did you forget to commit config/app-CLAUDE.md, or clone fresh?)\n' >&2
  exit 1
fi

TARGET="$AGENT_HUB_ROOT/CLAUDE.md"

# Tell `test -h` apart from `test -f` carefully: a symlink that points at a
# regular file will satisfy *both* -h and -f. We must check -h first.
if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  if [[ -L "$TARGET" ]]; then
    # Already a symlink. `ln -sf` will silently update it to point at our
    # canonical, which is the intended idempotent behavior.
    :
  elif [[ -f "$TARGET" ]]; then
    # All warn-branch output goes to stderr (>&2) so a calling wrapper that
    # captures stdout for "did anything happen?" detection still surfaces
    # the actionable recipe. Reviewer M5 PR #1 Suggestion 1.
    printf 'warning: %s is a regular file (not a symlink).\n' "$TARGET" >&2
    printf '  Skipping to avoid clobbering uncommitted local edits.\n' >&2
    printf '  To adopt its current content as the canonical:\n' >&2
    printf '    mv %s %s\n' "$TARGET" "$CANONICAL" >&2
    printf '    cd %s && git add -A && git commit -m "promote app/CLAUDE.md to canonical"\n' "$(cd "$SCRIPT_DIR/.." && pwd)" >&2
    printf '    %s\n' "$0" >&2
    exit 0
  else
    printf 'error: %s exists but is neither a regular file nor a symlink.\n' "$TARGET" >&2
    printf '  (a directory? a device node? please remove manually and re-run.)\n' >&2
    exit 1
  fi
fi

ln -sf "$CANONICAL" "$TARGET"
printf 'symlink: %s → %s\n' "$TARGET" "$CANONICAL"
