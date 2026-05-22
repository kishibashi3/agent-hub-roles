#!/bin/bash
# Collect per-peer daily cost from bridge logs.
# Usage: daily-cost.sh [YYYY-MM-DD]  (default: today)
# Output is written to /tmp/daily-cost.txt for @planner to consume.

DATE="${1:-$(date +%Y-%m-%d)}"
THRESHOLD="${COST_THRESHOLD:-10}"  # dollars, per peer
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${REPO_DIR}/daily/${DATE}-cost.md"
mkdir -p "${REPO_DIR}/daily"

total=0
high_cost_peers=()
output_lines=()

for log in /tmp/bridge-*.log; do
  [[ -f "$log" ]] || continue
  handle=$(basename "$log" .log | sed 's/^bridge-//')

  # Extract cost values for the given date
  costs=$(grep "^${DATE}" "$log" 2>/dev/null | grep -oP 'cost=\$\K[0-9.]+')
  [[ -z "$costs" ]] && continue

  # Daily cost = last value - first value (cumulative per session)
  first=$(echo "$costs" | head -1)
  last=$(echo "$costs" | tail -1)
  daily=$(awk "BEGIN {printf \"%.4f\", $last - $first}")

  output_lines+=("$handle: \$$daily")
  total=$(awk "BEGIN {printf \"%.4f\", $total + $daily}")

  over=$(awk "BEGIN {print ($daily >= $THRESHOLD) ? 1 : 0}")
  if [[ "$over" == "1" ]]; then
    high_cost_peers+=("$handle:\$$daily")
  fi
done

{
  for line in "${output_lines[@]}"; do echo "$line"; done
  echo "---"
  echo "total: \$$total"
  if [[ ${#high_cost_peers[@]} -gt 0 ]]; then
    echo "---"
    echo "HIGH COST (>= \$${THRESHOLD}/peer):"
    for p in "${high_cost_peers[@]}"; do echo "  $p"; done
  fi
  echo ""
  echo "generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
} | tee "$OUTPUT"

# Commit to operation repo
cd "$REPO_DIR"
git add "daily/${DATE}-cost.md"
git commit -m "cost: daily report ${DATE}"
git push
