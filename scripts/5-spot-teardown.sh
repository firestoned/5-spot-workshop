#!/usr/bin/env bash
# =============================================================================
# 5-spot-teardown.sh — fully remove everything a tier's setup created.
#
#   ./scripts/5-spot-teardown.sh --env-tier kind          # CAPD: mgmt + workload
#   ./scripts/5-spot-teardown.sh --env-tier hard          # k0smotron + remote node
#   ./scripts/5-spot-teardown.sh --env-tier codespaces    # same as kind, in-container
#   ./scripts/5-spot-teardown.sh --env-tier killercoda    # nothing (browser expires)
#   ./scripts/5-spot-teardown.sh --env-tier kind --purge  # also delete cloned repos/keys
#   ./scripts/5-spot-teardown.sh --env-tier hard --stop-colima  # also stop Colima (macOS)
#
# Teardown is best-effort and idempotent: every step tolerates "already gone".
# Mirrors what killercoda/*/setup-background.sh and Makefile `kind`/`hard` create.
# =============================================================================
set -uo pipefail

# ---- names/paths (keep in sync with killercoda/*/setup-background.sh) -------
MGMT_CLUSTER="5spot-mgmt"          # kind create cluster --name 5spot-mgmt
WORKLOAD_CLUSTER="dev-cluster"     # CAPD/k0smotron workload cluster name
WORKDIR="$HOME/5spot-workshop"
REPO_CLONE="$HOME/5-spot"
KUBECONFIG_FILE="$HOME/dev-cluster.kubeconfig"
SSH_KEY="$HOME/remote_key"
REMOTE_NODE_HOST="${REMOTE_NODE_HOST:-node02}"

TIER=""; PURGE=false; STOP_COLIMA=false
while [ $# -gt 0 ]; do
  case "$1" in
    --env-tier) TIER="${2:-}"; shift 2;;
    --purge) PURGE=true; shift;;
    --stop-colima) STOP_COLIMA=true; shift;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1 (try --help)"; exit 2;;
  esac
done

OS="$(uname -s)"
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yell()  { printf '\033[33m%s\033[0m\n' "$*"; }
have()  { command -v "$1" >/dev/null 2>&1; }

# ---- teardown steps ---------------------------------------------------------
delete_kind_mgmt() {
  if have kind && kind get clusters 2>/dev/null | grep -qx "$MGMT_CLUSTER"; then
    yell "  → deleting kind management cluster '$MGMT_CLUSTER'"
    kind delete cluster --name "$MGMT_CLUSTER" >/dev/null 2>&1 \
      && green "  ✓ mgmt cluster deleted" || red "  ✗ failed to delete mgmt cluster"
  else
    green "  ✓ no kind management cluster '$MGMT_CLUSTER'"
  fi
}

# CAPD provisions workload machines as standalone Docker containers (kind-labelled
# with the workload cluster name). Deleting the mgmt cluster does NOT remove them —
# they leak unless we clean them up explicitly.
delete_capd_workload() {
  have docker || { yell "  ⚠ docker not found — skipping CAPD workload cleanup"; return; }
  local ids
  ids="$(docker ps -aq \
    --filter "label=io.x-k8s.kind.cluster=${WORKLOAD_CLUSTER}" \
    --filter "name=${WORKLOAD_CLUSTER}" 2>/dev/null | sort -u)"
  if [ -n "$ids" ]; then
    yell "  → removing CAPD workload containers for '$WORKLOAD_CLUSTER'"
    docker rm -f $ids >/dev/null 2>&1 \
      && green "  ✓ workload containers removed" || red "  ✗ some workload containers survived"
  else
    green "  ✓ no CAPD workload containers"
  fi
  # kind sometimes registers the CAPD workload as its own cluster too.
  if have kind && kind get clusters 2>/dev/null | grep -qx "$WORKLOAD_CLUSTER"; then
    kind delete cluster --name "$WORKLOAD_CLUSTER" >/dev/null 2>&1 && green "  ✓ workload kind cluster deleted"
  fi
}

# k0smotron's RemoteMachine installs a k0s worker on REMOTE_NODE_HOST over SSH.
# Reset it so the host is clean for the next run (best-effort; needs reachability).
reset_remote_node() {
  if [ ! -f "$SSH_KEY" ]; then green "  ✓ no remote SSH key — nothing provisioned remotely"; return; fi
  local ip; ip="$(getent hosts "$REMOTE_NODE_HOST" 2>/dev/null | awk '{print $1}')"; ip="${ip:-$REMOTE_NODE_HOST}"
  yell "  → resetting k0s on remote node ${ip} (best-effort)"
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=8 -i "$SSH_KEY" "root@${ip}" \
       'k0s stop 2>/dev/null; k0s reset 2>/dev/null; rm -rf /etc/k0s /var/lib/k0s' >/dev/null 2>&1; then
    green "  ✓ remote k0s reset"
  else
    yell "  ⚠ could not reach/reset ${ip} — reset it manually if it's still up (k0s reset)"
  fi
}

clean_files() {
  $PURGE || { yell "  ⚠ keeping generated files (use --purge to delete $WORKDIR, $REPO_CLONE, keys)"; return; }
  yell "  → purging generated files"
  rm -rf "$WORKDIR" "$REPO_CLONE"
  rm -f  "$KUBECONFIG_FILE" "$SSH_KEY" "$SSH_KEY.pub"
  green "  ✓ generated files removed"
}

stop_colima() {
  [ "$OS" = Darwin ] || return
  $STOP_COLIMA || { yell "  ⚠ leaving Colima running (use --stop-colima to stop the macOS VM)"; return; }
  if have colima; then
    yell "  → stopping Colima"
    colima stop >/dev/null 2>&1 && green "  ✓ Colima stopped" || yell "  ⚠ Colima was not running"
  fi
}

# ---- tiers ------------------------------------------------------------------
[ -z "$TIER" ] && { red "required: --env-tier {killercoda|codespaces|kind|hard}"; exit 2; }
echo "5-Spot teardown — tier: $TIER  ($OS)  $($PURGE && echo PURGE)"
echo

case "$TIER" in
  killercoda)
    green "  ✓ Nothing to tear down — the Killercoda VM is discarded when the session ends."
    ;;

  kind|codespaces)
    # CAPD path (make kind / Codespaces pre-bake): mgmt kind cluster + workload containers.
    delete_capd_workload
    delete_kind_mgmt
    clean_files
    stop_colima
    ;;

  hard)
    # k0smotron path: mgmt kind cluster + hosted control plane (pods) + remote worker.
    reset_remote_node
    delete_capd_workload   # harmless if absent; covers mixed local rehearsals
    delete_kind_mgmt
    clean_files
    stop_colima
    ;;

  *) red "unknown tier '$TIER' — use killercoda|codespaces|kind|hard"; exit 2;;
esac

echo
green "✓ Tier '$TIER' torn down."
