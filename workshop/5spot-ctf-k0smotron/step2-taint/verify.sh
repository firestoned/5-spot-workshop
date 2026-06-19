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
# Flag 2 — the spot-tolerating workload is Running on a node that carries the spot taint.
WL=$HOME/dev-cluster.kubeconfig
phase=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
node=$(kubectl --kubeconfig "$WL" get pods -l app=batch-cruncher -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
tainted=false
if [ -n "$node" ]; then
  kubectl --kubeconfig "$WL" get node "$node" -o jsonpath='{.spec.taints[*].key}' 2>/dev/null | grep -q 'workshop.example.com/spot' && tainted=true
fi
if [ "$phase" = "Running" ] && [ "$tainted" = "true" ]; then
  echo "✅ batch-cruncher is Running on tainted spot capacity ($node)."
  echo "🏁 FLAG{COMPLIANT_WORKLOAD_RIDES_SPOT}"
  post_flag "FLAG{COMPLIANT_WORKLOAD_RIDES_SPOT}"
  exit 0
fi
echo "Not yet (phase='$phase', node='$node', tainted='$tainted')."
echo "  • kubectl --kubeconfig $WL describe pod -l app=batch-cruncher | tail -20"
exit 1
