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
# Flag 3 — window closed: SM Inactive and no workers remain on the workload cluster.
MGMT=kind-5spot-mgmt
WL=$HOME/dev-cluster.kubeconfig
phase=$(kubectl --context "$MGMT" get sm business-hours-worker -o jsonpath='{.status.phase}' 2>/dev/null || true)
nodes=$(kubectl --kubeconfig "$WL" get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$phase" = "Inactive" ] && [ "${nodes:-1}" -eq 0 ]; then
  echo "✅ Window closed. Worker drained + remote host released; phase=Inactive."
  echo "🏁 FLAG{GRACEFUL_DRAIN_SURVIVED}"
  post_flag "FLAG{GRACEFUL_DRAIN_SURVIVED}"
  exit 0
fi
echo "Not yet (phase='$phase', worker_nodes='$nodes'). Drain respects the grace period — give it a moment."
echo "  • kubectl --context $MGMT logs -n 5spot-system deploy/5spot-controller | tail -30"
exit 1
