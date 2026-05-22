Show current bridge status: inventory vs actual.

Usage: /status

Steps:
1. Read bridge-inventory.md "Currently running"
2. Call get_participants to get is_online for each handle
3. Run `pgrep -fa agent-hub-bridge-claude` for PID info
4. Display table: handle | workdir | is_online | pid | task
