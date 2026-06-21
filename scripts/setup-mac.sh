#!/usr/bin/env bash
# =============================================================================
# setup-mac.sh — Hard tier on macOS, Colima-first.
#
# Checks for (and installs if missing): Homebrew, Colima, docker CLI, kubectl,
# kind, clusterctl (pinned line), helm, k0sctl, flux — then starts Colima sized
# for the workshop and optionally brings the k0smotron stack up.
#
#   ./scripts/setup-mac.sh            # install + start colima
#   ./scripts/setup-mac.sh --up       # ...and run the k0smotron pre-bake locally
#   ./scripts/setup-mac.sh --check    # report only, change nothing
#
# "Hard" means production-faithful, not compiled-from-source — building the
# controller (make kind-load) is optional. Docs: https://5spot.finos.org/
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."   # repo root

[ "$(uname -s)" = "Darwin" ] || { echo "This script is macOS-only. Linux: use scripts/5-spot-bootstrap.sh --env-tier hard. Windows: use Codespaces or the iximiuz browser lab."; exit 2; }

MODE="install"
case "${1:-}" in --check) MODE=check;; --up) MODE=up;; esac

echo "═══ 5-Spot Hard tier (macOS / Colima) ═══"
echo

# 1) Tooling via the shared bootstrap (single source of truth for pins)
if [ "$MODE" = check ]; then
  ./scripts/5-spot-bootstrap.sh --env-tier hard --check-only; exit $?
fi
./scripts/5-spot-bootstrap.sh --env-tier hard || exit 1

# 2) Colima sizing sanity — kind + CAPI + k0smotron + workers want headroom
echo
echo "── Colima profile check ──"
# colima reports memory in bytes; warn below 8 GiB
MEM_OK=$(colima status --json 2>/dev/null | python3 -c "import sys,json;print(1 if json.load(sys.stdin).get('memory',0) >= 8*1024**3 else 0)" 2>/dev/null || echo 1)
if [ "$MEM_OK" != "1" ]; then
  echo "⚠ Colima has <8GiB. Recommend: colima stop && colima start --cpu 4 --memory 8 --disk 60"
fi
docker info >/dev/null 2>&1 && echo "✓ docker (colima) is up" || { echo "✗ docker unreachable"; exit 1; }

# 3) Optional: second Lima VM as a RemoteMachine SSH target (the 'real' worker)
cat <<'EOF'

── Optional: a real SSH target for RemoteMachine ──
The k0smotron track provisions a worker over SSH. Locally, the easiest target is a
second Colima/Lima VM:

  colima start --profile node1 --cpu 2 --memory 2
  colima ssh --profile node1 -- sudo sh -c 'echo PermitRootLogin yes >> /etc/ssh/sshd_config && systemctl restart sshd' 
  colima ls            # note node1's IP → use it as RemoteMachine address

(Confidential Containers ⭐⭐ note: Apple Silicon cannot run x86 TEEs — do the CoCo
bonus on a Linux host with /dev/kvm instead.)
EOF

# 4) Optionally bring the stack up now
if [ "$MODE" = up ]; then
  echo
  echo "── Bringing up the k0smotron stack locally (this takes several minutes) ──"
  REMOTE_NODE_HOST="${REMOTE_NODE_HOST:-}" bash workshop/5spot-ctf-k0smotron/setup-background.sh
fi

echo
echo "✓ Mac Hard tier ready. Next: docs/quickstart-tiers.md → 'Hard (local)'."
