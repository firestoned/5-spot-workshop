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
# Bonus — the ScheduledMachine is managed by Flux (kustomize-controller), not kubectl.
MGMT=kind-5spot-mgmt

ks_ready=$(kubectl --context "$MGMT" get kustomization -n flux-system scheduledmachine \
  -o jsonpath='{range .status.conditions[?(@.type=="Ready")]}{.status}{end}' 2>/dev/null || true)
managed=$(kubectl --context "$MGMT" get sm business-hours-worker \
  -o jsonpath='{.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}' 2>/dev/null || true)

if [ "$ks_ready" = "True" ] && [ -n "$managed" ]; then
  echo "✅ Flux Kustomization is Ready and the ScheduledMachine is GitOps-managed."
  echo "⭐ FLAG{GITOPS_SCHEDULE_RECONCILED_BY_FLUX}"
  post_flag "FLAG{GITOPS_SCHEDULE_RECONCILED_BY_FLUX}"
  exit 0
fi

echo "Not yet (kustomization Ready='$ks_ready', SM flux-managed-by='$managed')."
echo "Hints:"
echo "  • kubectl --context $MGMT get fluxinstance -n flux-system"
echo "  • kubectl --context $MGMT get gitrepository,kustomization -n flux-system"
echo "  • flux-operator + FluxInstance must be Ready before the Kustomization reconciles."
exit 1
