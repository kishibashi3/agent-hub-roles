#!/usr/bin/env bash
# spawn-bridge.sh — bridge worker を起動して inventory を更新する
#
# 使い方: spawn-bridge.sh --user <handle> --workdir <path> [--type <engine>] [--tenant <t>]
#
# --type: bridge-claude (default) | bridge-gemini | bridge-adk | bridge-slack
#         対応する AGENT_HUB_BRIDGE_<TYPE>_BIN 環境変数を参照
#         AGENT_HUB_BRIDGE_BIN で明示 override も可
#
# inventory ファイル:
#   BRIDGE_INVENTORY 環境変数 (未設定なら自動検出)

set -euo pipefail

if [[ -z "${BRIDGE_INVENTORY:-}" ]]; then
    : "${AGENT_HUB_ROLES:?AGENT_HUB_ROLES is not set — add it to .bashrc}"
    project_key=$(echo "$AGENT_HUB_ROLES" | sed 's|/|-|g')
    BRIDGE_INVENTORY="$HOME/.claude/projects/${project_key}/bridge-inventory.md"
fi

user_handle=""
workdir=""
tenant=""
bridge_type="bridge-claude"
weight=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)    user_handle="$2"; shift 2 ;;
        --workdir) workdir="$2"; shift 2 ;;
        --tenant)  tenant="$2"; shift 2 ;;
        --type)    bridge_type="$2"; shift 2 ;;
        --weight)  weight="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ -z "$user_handle" || -z "$workdir" ]]; then
    echo "usage: $0 --user <handle> --workdir <path> [--type bridge-claude|bridge-gemini|...] [--tenant <t>] [--weight heavy|middle|light]" >&2
    exit 2
fi

# weight → ANTHROPIC_MODEL 解決
# env var AGENT_HUB_BRIDGE_MODEL_{HEAVY,MIDDLE,LIGHT} でオーバーライド可能
if [[ -n "$weight" ]]; then
    weight_upper="${weight^^}"
    model_env_var="AGENT_HUB_BRIDGE_MODEL_${weight_upper}"
    resolved_model="${!model_env_var:-}"
    if [[ -z "$resolved_model" ]]; then
        case "$weight" in
            heavy)  resolved_model="claude-opus-4-7" ;;
            middle) resolved_model="claude-sonnet-4-6" ;;
            light)  resolved_model="claude-haiku-4-5" ;;
            *) echo "unknown weight: $weight (use heavy|middle|light)" >&2; exit 2 ;;
        esac
    fi
    export ANTHROPIC_MODEL="$resolved_model"
    echo "weight=${weight} → ANTHROPIC_MODEL=${resolved_model}" >&2
fi

# バイナリ解決
if [[ -n "${AGENT_HUB_BRIDGE_BIN:-}" ]]; then
    BINARY="$AGENT_HUB_BRIDGE_BIN"
else
    # --type から env var 名を導出: bridge-claude → AGENT_HUB_BRIDGE_CLAUDE_BIN
    type_upper="${bridge_type//-/_}"
    type_upper="${type_upper^^}"
    env_var="AGENT_HUB_${type_upper}_BIN"
    bin_path="${!env_var:-}"

    if [[ -n "$bin_path" ]]; then
        BINARY="$bin_path"
    elif command -v "agent-hub-${bridge_type}" &>/dev/null; then
        BINARY="$(command -v "agent-hub-${bridge_type}")"
    else
        echo "error: binary for --type=${bridge_type} not found. Set ${env_var} or add agent-hub-${bridge_type} to PATH." >&2
        exit 2
    fi
fi

LOG="/tmp/bridge-${user_handle}.log"
: > "$LOG"

cmd=("$BINARY" --user "$user_handle" --workdir "$workdir")
[[ -n "$tenant" ]] && cmd+=(--tenant "$tenant")

echo "starting @${user_handle} (type=${bridge_type}, workdir=${workdir}, log=${LOG})" >&2
nohup "${cmd[@]}" >> "$LOG" 2>&1 &
PID=$!

# listening on inbox を待つ (最大 15 秒)
for i in $(seq 1 30); do
    if grep -q "listening on inbox" "$LOG" 2>/dev/null; then
        break
    fi
    sleep 0.5
done

if ! grep -q "listening on inbox" "$LOG" 2>/dev/null; then
    echo "timeout waiting for 'listening on inbox'" >&2
    exit 1
fi

echo "ok pid=${PID}" >&2
echo "$PID"

# inventory 更新
if [[ -f "$BRIDGE_INVENTORY" ]]; then
    NOW=$(date '+%Y-%m-%d %H:%M')
    TENANT_LABEL="${tenant:-default}"

    sed -i "/^| handle | tenant/a | \`@${user_handle}\` | \`${TENANT_LABEL}\` | \`${workdir}\` | \`${LOG}\` | — | ${PID} | ${NOW} | this session |" "$BRIDGE_INVENTORY"
    sed -i "/^新しいエントリを上に追加/a - ${NOW} — **start** \`@${user_handle}\` (tenant=${TENANT_LABEL}, workdir=${workdir}, type=${bridge_type}) — pid=${PID}" "$BRIDGE_INVENTORY"

    echo "inventory updated: $BRIDGE_INVENTORY" >&2
fi
