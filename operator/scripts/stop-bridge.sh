#!/usr/bin/env bash
# stop-bridge.sh — bridge worker を停止して inventory を更新する
#
# 使い方: stop-bridge.sh --user <handle>
#
# BRIDGE_INVENTORY 環境変数で inventory ファイルを指定可 (未設定なら自動検出)

set -euo pipefail

if [[ -z "${BRIDGE_INVENTORY:-}" ]]; then
    : "${AGENT_HUB_ROLES:?AGENT_HUB_ROLES is not set — add it to .bashrc}"
    project_key=$(echo "$AGENT_HUB_ROLES" | sed 's|/|-|g')
    BRIDGE_INVENTORY="$HOME/.claude/projects/${project_key}/bridge-inventory.md"
fi

user_handle=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) user_handle="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$user_handle" ]]; then
    echo "usage: $0 --user <handle>" >&2
    exit 2
fi

# PID を pgrep で探す
PID=$(pgrep -f "agent-hub-bridge-claude --user ${user_handle} " | head -1 || true)

if [[ -z "$PID" ]]; then
    echo "warning: no running process found for @${user_handle}" >&2
else
    kill "$PID" 2>/dev/null && echo "killed pid=${PID}" >&2 || echo "warning: kill failed for pid=${PID}" >&2
fi

# inventory 更新
if [[ -f "$BRIDGE_INVENTORY" ]]; then
    NOW=$(date '+%Y-%m-%d %H:%M')

    # "Currently running" から該当行を削除
    sed -i "/\`@${user_handle}\`/d" "$BRIDGE_INVENTORY"

    # "Activity log" に stop エントリを追加
    sed -i "/^新しいエントリを上に追加/a - ${NOW} — **stop** \`@${user_handle}\` — pid=${PID:-unknown}" "$BRIDGE_INVENTORY"

    echo "inventory updated: $BRIDGE_INVENTORY" >&2
fi
