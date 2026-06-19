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
# ⭐⭐ CoCo bonus — a pod is Running under a kata/coco RuntimeClass on the spot node.
WL=$HOME/dev-cluster.kubeconfig
phase=$(kubectl --kubeconfig "$WL" get pods -l app=confidential-cruncher -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)
rc=$(kubectl --kubeconfig "$WL" get pods -l app=confidential-cruncher -o jsonpath='{.items[0].spec.runtimeClassName}' 2>/dev/null || true)
node=$(kubectl --kubeconfig "$WL" get pods -l app=confidential-cruncher -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || true)
tainted=false
[ -n "$node" ] && kubectl --kubeconfig "$WL" get node "$node" -o jsonpath='{.spec.taints[*].key}' 2>/dev/null | grep -q 'workshop.example.com/spot' && tainted=true
if [ "$phase" = "Running" ] && printf '%s' "$rc" | grep -qiE 'kata|coco' && [ "$tainted" = "true" ]; then
  echo "✅ Confidential pod Running under '$rc' on spot node $node."
  echo "🏁🏁 FLAG{CONFIDENTIAL_WORKLOAD_ON_SPOT_TEE}"
  post_flag "FLAG{CONFIDENTIAL_WORKLOAD_ON_SPOT_TEE}"
  exit 0
fi
echo "Not yet (phase='$phase', runtimeClass='$rc', node='$node', spot-tainted='$tainted')."
echo "Hints:"
echo "  • RuntimeClasses present? kubectl --kubeconfig $WL get runtimeclass"
echo "  • Worker needs /dev/kvm (nested virt). kind nodes: use kata-clh, not kata-qemu-coco-dev."
echo "  • kubectl --kubeconfig $WL describe pod -l app=confidential-cruncher | tail -30"
echo "  • Docs: https://confidentialcontainers.org/docs/getting-started/"
exit 1
