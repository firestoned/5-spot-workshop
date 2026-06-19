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
# Flag 3 — window closed: SM is Inactive and the worker node is gone (drained + deleted).
MGMT=kind-5spot-mgmt
WL=$HOME/dev-cluster.kubeconfig
NODE=business-hours-worker

phase=$(kubectl --context "$MGMT" get sm business-hours-worker \
  -o jsonpath='{.status.phase}' 2>/dev/null || true)
node_gone=true
kubectl --kubeconfig "$WL" get node "$NODE" >/dev/null 2>&1 && node_gone=false

if [ "$phase" = "Inactive" ] && [ "$node_gone" = "true" ]; then
  echo "✅ Window closed. 5-Spot drained and removed the worker; phase=Inactive."
  echo "🏁 FLAG{GRACEFUL_DRAIN_SURVIVED}"
  post_flag "FLAG{GRACEFUL_DRAIN_SURVIVED}"
  exit 0
fi

echo "Not yet (phase='$phase', worker_removed='$node_gone')."
echo "Hints:"
echo "  • Did you set spec.schedule.enabled=false?"
echo "  • Drain respects gracefulShutdownTimeout/nodeDrainTimeout — give it a moment."
echo "  • kubectl --context $MGMT logs -n 5spot-system deploy/5spot-controller | tail -30"
exit 1
