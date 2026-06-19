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
# Flag 1 — a remote-provisioned k0s worker has joined the workload cluster.
WL=$HOME/dev-cluster.kubeconfig
ready=$(kubectl --kubeconfig "$WL" get nodes \
  -o jsonpath='{range .items[*]}{range .status.conditions[?(@.type=="Ready")]}{.status}{"\n"}{end}{end}' 2>/dev/null | grep -c True || true)
if [ "${ready:-0}" -ge 1 ]; then
  echo "✅ A remote k0s worker joined dev-cluster and is Ready."
  echo "🏁 FLAG{5SPOT_REMOTE_WORKER_PROVISIONED}"
  post_flag "FLAG{5SPOT_REMOTE_WORKER_PROVISIONED}"
  exit 0
fi
echo "Not yet — no Ready worker on the workload cluster."
echo "Hints:"
echo "  • kubectl --context kind-5spot-mgmt get remotemachine,machine -A"
echo "  • kubectl --context kind-5spot-mgmt describe remotemachine business-hours-worker"
echo "  • SSH reachability to the remote host + the remote-ssh-key Secret are the usual culprits."
echo "  • docs.k0smotron.io (capi-remote) · https://5spot.finos.org/operations/troubleshooting/"
exit 1
