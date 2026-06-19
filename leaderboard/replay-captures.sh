#!/usr/bin/env bash
# =============================================================================
# replay-captures.sh — push locally-recorded flag captures to the flagboard.
#
# Each step's verify.sh ALWAYS appends captures to ~/.flagboard-captures.jsonl,
# even when the flagboard REST API is down or not up yet. Run this once the board
# is reachable to backfill everything. Duplicate (player,flag) posts return 200
# server-side, so re-running is safe and idempotent.
#
#   FLAGBOARD_URL=http://localhost:5050 leaderboard/replay-captures.sh
#   leaderboard/replay-captures.sh         # reads FLAGBOARD_URL from ~/.flagboard
#   FLAGBOARD_CAPTURES=/path/to.jsonl leaderboard/replay-captures.sh
# =============================================================================
set -uo pipefail

[ -f "$HOME/.flagboard" ] && . "$HOME/.flagboard"
LOG="${FLAGBOARD_CAPTURES:-$HOME/.flagboard-captures.jsonl}"
URL="${FLAGBOARD_URL:-}"

[ -n "$URL" ] || { echo "set FLAGBOARD_URL (env or ~/.flagboard) — e.g. http://localhost:5050"; exit 2; }
[ -f "$LOG" ] || { echo "no local captures at $LOG — nothing to replay"; exit 0; }

ok=0; fail=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  if curl -m 5 -fsS -X POST "${URL%/}/api/flag" -H 'Content-Type: application/json' \
       -d "$line" >/dev/null 2>&1; then
    ok=$((ok+1))
  else
    fail=$((fail+1)); echo "  ✗ rejected: $line"
  fi
done < "$LOG"

echo "replayed $ok capture(s) to $URL; $fail failed."
[ "$fail" -eq 0 ]
