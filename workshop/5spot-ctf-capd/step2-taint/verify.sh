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
# Flag 2 — the spot-tolerating workload is Running ON the tainted spot node.
WL=$HOME/dev-cluster.kubeconfig
# CAPD registers the node as <cluster>-<scheduledmachine> — match by suffix.
NODE=$(kubectl --kubeconfig "$WL" get nodes -o name 2>/dev/null | sed 's|^node/||' | grep -E 'business-hours-worker$' | head -1)

phase=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
onnode=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher \
  -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)

if [ "$phase" = "Running" ] && [ -n "$NODE" ] && [ "$onnode" = "$NODE" ]; then
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
