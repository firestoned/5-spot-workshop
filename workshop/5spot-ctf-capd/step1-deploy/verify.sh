#!/usr/bin/env bash

# --- flagboard auto-post (best-effort) + always-on local record -------------
# Join once:  printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "your-team" "https://..." > ~/.flagboard
post_flag() {
  [ -f "$HOME/.flagboard" ] && . "$HOME/.flagboard"
  STEP="$(basename "$(cd "$(dirname "$0")" && pwd)")"
  PLAYER="${PLAYER:-$(id -un)}"
  REC="{\"player\":\"$PLAYER\",\"flag\":\"$1\",\"step\":\"$STEP\",\"ts\":$(date +%s)}"
  # Always keep a local record — survives a missing/unreachable flagboard.
  printf '%s\n' "$REC" >> "$HOME/.flagboard-captures.jsonl"
  # Best-effort POST; if the REST API is down, the local record above stands in.
  if [ -n "${FLAGBOARD_URL:-}" ]; then
    curl -m 3 -fsS -X POST "${FLAGBOARD_URL%/}/api/flag" -H 'Content-Type: application/json' \
      -d "$REC" >/dev/null 2>&1 \
      || echo "  (flagboard unreachable — capture saved to ~/.flagboard-captures.jsonl)"
  fi
}
# -----------------------------------------------------------------------------
# Flag 1 — the scheduled worker has joined the workload cluster and is Ready.
WL=$HOME/dev-cluster.kubeconfig
# CAPD registers the node as <cluster>-<scheduledmachine> (e.g.
# dev-cluster-business-hours-worker), so match by suffix instead of hardcoding the
# cluster prefix — the worker is the only node ending in "business-hours-worker".
NODE=$(kubectl --kubeconfig "$WL" get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E 'business-hours-worker$' | head -1)

status=$(kubectl --kubeconfig "$WL" get node "$NODE" \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}' 2>/dev/null || true)

if [ -n "$NODE" ] && [ "$status" = "True" ]; then
  echo "✅ $NODE is Ready — 5-Spot opened the window and the worker joined."
  echo "🏁 FLAG{5SPOT_WINDOW_OPEN_WORKER_JOINED}"
  post_flag "FLAG{5SPOT_WINDOW_OPEN_WORKER_JOINED}"
  exit 0
fi

echo "Not yet. The worker isn't Ready on the workload cluster."
echo "Hints:"
echo "  • kubectl --context kind-5spot-mgmt get sm business-hours-worker -o wide"
echo "  • kubectl --context kind-5spot-mgmt describe machine business-hours-worker"
echo "  • kubectl --kubeconfig $WL get nodes"
exit 1
