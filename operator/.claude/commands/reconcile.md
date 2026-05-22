Reconcile bridge-inventory.md against actual running processes.

Usage: /reconcile

Steps:
1. Run `pgrep -fa agent-hub-bridge-claude` to get actual running processes
2. Call get_participants and check is_online for each handle in inventory
3. Compare with bridge-inventory.md "Currently running"
4. For any discrepancy: update inventory (remove dead entries, add missing ones)
5. Report what changed
