#!/usr/bin/env bash

# --- flagboard auto-post (optional, fire-and-forget) -------------------------
# Join once:  printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "your-team" "https://..." > ~/.flagboard
post_flag() {
  [ -f "$HOME/.flagboard" ] && . "$HOME/.flagboard"
  [ -n "${FLAGBOARD_URL:-}" ] && [ -n "${PLAYER:-}" ] || return 0
  STEP="$(basename "$(cd "$(dirname "$0")" && pwd)")"
  curl -m 3 -fsS -X POST "${FLAGBOARD_URL%/}/api/flag" -H 'Content-Type: application/json' \
    -d "{\"player\":\"$PLAYER\",\"flag\":\"$1\",\"step\":\"$STEP\"}" >/dev/null 2>&1 || true
}
# -----------------------------------------------------------------------------
# Flag 1 — the scheduled worker has joined the workload cluster and is Ready.
WL=$HOME/dev-cluster.kubeconfig
NODE=business-hours-worker

status=$(kubectl --kubeconfig "$WL" get node "$NODE" \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}' 2>/dev/null || true)

if [ "$status" = "True" ]; then
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
