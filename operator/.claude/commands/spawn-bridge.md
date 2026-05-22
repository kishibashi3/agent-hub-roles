Spawn a bridge worker and update inventory.

Usage: /spawn-bridge --user <handle> --workdir <path> [--tenant <tenant>] [--message "初期指示"]

Steps:
1. Run in background: `operator/scripts/spawn-bridge.sh --user <handle> --workdir <workdir> [--tenant <tenant>]`
   - Returns PID on success, exits non-zero on timeout
2. Confirm `listening on inbox` (script handles this wait)
3. If --message is given, send via send_message to @<handle>
4. Update bridge-inventory.md: add row to "Currently running", add start entry to "Activity log"
