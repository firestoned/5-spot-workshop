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
# Flag 2 — the spot-tolerating workload is Running ON the tainted spot node.
WL=$HOME/dev-cluster.kubeconfig
NODE=business-hours-worker

phase=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
onnode=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher \
  -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)

if [ "$phase" = "Running" ] && [ "$onnode" = "$NODE" ]; then
  echo "✅ batch-cruncher is Running on $NODE — it tolerated the spot taint."
  echo "🏁 FLAG{COMPLIANT_WORKLOAD_RIDES_SPOT}"
  post_flag "FLAG{COMPLIANT_WORKLOAD_RIDES_SPOT}"
  exit 0
fi

echo "Not yet. Need batch-cruncher Running on $NODE (phase='$phase', node='$onnode')."
echo "Hints:"
echo "  • Did the worker keep its taint? kubectl --kubeconfig $WL describe node $NODE | grep -i taint"
echo "  • kubectl --kubeconfig $WL describe pod -l app=batch-cruncher | tail -20"
exit 1
