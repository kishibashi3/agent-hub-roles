Send the same message to multiple participants.

Usage: /broadcast --message "..." [--to handle1,handle2,...]

Steps:
1. If --to is given, send to each specified handle
2. If --to is omitted, send to all online participants (excluding self) from get_participants
3. Report sent message IDs
