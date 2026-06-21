#!/usr/bin/env bash
# =============================================================================
# test-iximiuz-live.sh — REAL end-to-end smoke test on an iximiuz playground.
#
# Boots the challenge's base playground, runs the SAME pre-bake + flag verifiers
# the published challenge runs (clones firestoned/5-spot-workshop and execs
# workshop/<scenario>/*), reports pass/fail, then tears the playground down.
# Catches iximiuz-environment-specific issues that `make test-live-kind` (local
# Docker) cannot — e.g. the inotify-limit footgun, or k0smotron's MiniLAN SSH.
#
#   ./scripts/test-iximiuz-live.sh                 # CAPD on the `docker` playground
#   ./scripts/test-iximiuz-live.sh k0smotron       # k0smotron on `mini-lan-ubuntu-docker`
#   ./scripts/test-iximiuz-live.sh [scenario] --keep        # leave the playground up
#   ./scripts/test-iximiuz-live.sh [scenario] --free-tier   # run as a free-tier user
#
# Needs: labctl installed + authenticated (`labctl auth login`). Consumes a real
# playground session on YOUR iximiuz account. Tests the code on firestoned/main
# (the init task clones it), NOT your working tree — push first.
# Docs: docs/iximiuz-setup.md
# =============================================================================
set -uo pipefail
export PATH="$HOME/.iximiuz/labctl/bin:$PATH"

REPO="${WORKSHOP_REPO_URL:-https://github.com/firestoned/5-spot-workshop}"
SCENARIO="capd"; KEEP=false; FREE=""
while [ $# -gt 0 ]; do case "$1" in
  capd|k0smotron) SCENARIO="$1"; shift;;
  --keep) KEEP=true; shift;;
  --free-tier) FREE="--as-free-tier-user"; shift;;
  -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
  *) echo "usage: $0 [capd|k0smotron] [--keep] [--free-tier]"; exit 2;;
esac; done

# ---- per-scenario config ----------------------------------------------------
case "$SCENARIO" in
  capd)
    PLAYGROUND="docker"; DIR="5spot-ctf-capd"; MACHINE=""
    PREBAKE="bash /opt/wk/workshop/$DIR/setup-background.sh"
    SM_FILE="scheduledmachine-business-hours.yaml"; POLL=24; LABEL="CAPD"
    # v0.2.2 / v1alpha1: schedule is inline — disable it to trigger the drain.
    SCHEDULE_OFF='{"spec":{"schedule":{"enabled":false}}}'
    ;;
  k0smotron)
    # Multi-node MiniLAN: node-01 = mgmt, node-02 = RemoteMachine SSH target.
    PLAYGROUND="mini-lan-ubuntu-docker"; DIR="5spot-ctf-k0smotron"; MACHINE="node-01"
    PREBAKE="REMOTE_NODE_HOST=node-02 bash /opt/wk/workshop/$DIR/setup-background.sh"
    SM_FILE="scheduledmachine-k0smotron.yaml"; POLL=40; LABEL="k0smotron"  # heavier → poll longer
    # v1beta1 / ADR-0009: schedule is a provider ref — flip the SM master switch instead.
    SCHEDULE_OFF='{"spec":{"enabled":false}}'
    ;;
esac

red(){ printf '\033[31m%s\033[0m\n' "$*"; }; grn(){ printf '\033[32m%s\033[0m\n' "$*"; }

command -v labctl >/dev/null 2>&1 || { red "✗ labctl not found — see docs/iximiuz-setup.md §1"; exit 1; }
labctl auth whoami 2>&1 | grep -qi "not logged in" && { red "✗ not authenticated — run: labctl auth login"; exit 1; }

echo "==> [$LABEL] Starting iximiuz '$PLAYGROUND' playground ${FREE:+(free-tier user) }…"
PID="$(labctl playground start $FREE -q "$PLAYGROUND")" || { red "✗ failed to start playground"; exit 1; }
[ -n "$PID" ] || { red "✗ no playground id returned"; exit 1; }
echo "    playground: $PID"
cleanup(){ if $KEEP; then echo "==> --keep: leaving $PID running (stop it: labctl playground stop $PID)"; \
  else echo "==> Stopping playground $PID"; labctl playground stop "$PID" >/dev/null 2>&1 || true; fi; }
trap cleanup EXIT

# Run a command on the playground AS ROOT (challenge tasks run as root/HOME=/root,
# but `labctl ssh` logs in as the non-root `laborant`). base64 so the multi-line
# script survives SSH arg-flattening as one token. On multi-node, target $MACHINE.
run(){
  local b; b="$(printf 'export HOME=/root\n%s' "$1" | base64 | tr -d '\n')"
  labctl ssh "$PID" ${MACHINE:+--machine "$MACHINE"} -- "echo $b | base64 -d | sudo bash"
}

echo "==> Waiting for the playground to accept SSH…"
ready=false
for i in $(seq 1 30); do run 'true' >/dev/null 2>&1 && { ready=true; break; }; sleep 10; done
$ready || { red "✗ playground never became reachable over SSH"; exit 1; }

echo "==> Pre-bake (same as the challenge init task — clone + setup-background.sh)…"
if ! run "set -e; [ -d /opt/wk/.git ] || git clone --depth 1 $REPO /opt/wk; $PREBAKE"; then
  red "✗ pre-bake FAILED — inspect with: labctl ssh $PID ${MACHINE:+--machine $MACHINE}  (then tail -f /tmp/5spot-setup.log)"; exit 1
fi
grn "  ✓ pre-bake completed"

echo "==> Applying the ScheduledMachine ($SM_FILE)…"
run "kubectl --context kind-5spot-mgmt apply -f \$HOME/5spot-workshop/$SM_FILE" || true

PASS=0; FAIL=0
flag(){ # label  verify-rel-path
  echo "  → $1"
  if run "for i in \$(seq 1 $POLL); do bash /opt/wk/workshop/$DIR/$2 >/dev/null 2>&1 && exit 0; sleep 15; done; exit 1"; then
    grn "    ✓ $1"; PASS=$((PASS+1))
  else
    red "    ✗ $1"; FAIL=$((FAIL+1))
  fi
}

flag "Flag 1 — worker joins"       "step1-deploy/verify.sh"
run "kubectl --kubeconfig \$HOME/dev-cluster.kubeconfig apply -f \$HOME/5spot-workshop/spot-workload.yaml" >/dev/null 2>&1 || true
flag "Flag 2 — stay compliant"     "step2-taint/verify.sh"
run "kubectl --context kind-5spot-mgmt patch sm business-hours-worker --type merge -p '$SCHEDULE_OFF'" >/dev/null 2>&1 || true
flag "Flag 3 — survive the drain"  "step3-drain/verify.sh"

echo ""
if [ "$FAIL" -eq 0 ]; then grn "━━ iximiuz $LABEL live: $PASS passed, 0 failed ━━"; else red "━━ iximiuz $LABEL live: $PASS passed, $FAIL failed ━━"; fi
[ "$FAIL" -eq 0 ]
