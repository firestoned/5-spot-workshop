#!/usr/bin/env bash
# =============================================================================
# 5-Spot CTF — REAL tier pre-bake (k0s + k0smotron, RemoteMachine over SSH)
#
# Topology (multi-node lab, e.g. mini-lan node-01..node-04):
#   node-01: kind management cluster (CAPI core + k0smotron providers + 5-Spot)
#            + a HOSTED workload control plane (K0smotronControlPlane).
#   node-02: the SSH target a scheduled k0s worker (RemoteMachine) is provisioned onto.
#
# 📚 k0smotron install: https://docs.k0smotron.io   |  5-Spot: https://5spot.finos.org/
#
# ⚠️ DRAFT + UNVALIDATED end-to-end. Smoke-test on a real 2-node env and reconcile
#    versions/fields with your installed k0smotron release before the workshop.
# =============================================================================
set -euo pipefail
LOGFILE="$( [ -w /opt ] && echo /opt/5spot-setup.log || echo /tmp/5spot-setup.log )"
exec > >(tee -a "$LOGFILE") 2>&1
echo "==> 5-Spot CTF (k0smotron) pre-bake starting $(date -u)"

# ---- Version pins -----------------------------------------------------------
KIND_NODE_IMAGE="kindest/node:v1.31.0"
CLUSTERCTL_VERSION="v1.9.5"                   # must serve cluster.x-k8s.io/v1beta1
FIVESPOT_IMAGE="ghcr.io/finos/5-spot:v0.2.2"  # CONFIRM exact published tag
CERT_MANAGER_VERSION="v1.15.3"
MGMT="kind-5spot-mgmt"
REMOTE_NODE_HOST="${REMOTE_NODE_HOST:-node-02}"  # remote SSH target host; override for your environment

# ---- Attendee quality-of-life: kubectl aliases + completion ----------------
# Single source of truth: workshop/shared/kubectl-aliases.sh, wired into the
# shell startup files by workshop/shared/install-aliases.sh. Locate the installer
# relative to this script, with fallbacks for the cloned-repo layouts.
install_shell_aliases() {
  local inst
  for inst in "$(dirname "$0")/../shared/install-aliases.sh" \
              "/opt/wk/workshop/shared/install-aliases.sh" \
              "$HOME/5-spot-workshop/workshop/shared/install-aliases.sh"; do
    [ -f "$inst" ] && { bash "$inst"; return 0; }
  done
  echo "  (workshop/shared/install-aliases.sh not found — skipping kubectl aliases)"
}

# ---- Tooling ---------------------------------------------------------------
# Install the pinned CLIs only if MISSING. A browser-lab host runs standalone as root with
# nothing pre-installed; Codespaces/local already have them and run as a non-root
# user who can't write the root-owned /usr/local/bin (curl error 23). Skip what's
# present, sudo when needed.
ARCH="$(uname -m)"; case "$ARCH" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; esac
SUDO=""; [ -w /usr/local/bin ] || SUDO="sudo"
install_bin() { # name url
  local tmp; tmp="$(mktemp)"
  echo "==> Installing $1"
  curl -fsSL "$2" -o "$tmp" && $SUDO install -m0755 "$tmp" "/usr/local/bin/$1"; rm -f "$tmp"
}
command -v kind      >/dev/null 2>&1 || install_bin kind      "https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-${ARCH}"
command -v kubectl   >/dev/null 2>&1 || install_bin kubectl   "https://dl.k8s.io/release/v1.31.0/bin/linux/${ARCH}/kubectl"
command -v clusterctl>/dev/null 2>&1 || install_bin clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-${ARCH}"
if ! command -v helm >/dev/null 2>&1; then
  echo "==> Installing helm (Flux bonus + CoCo bonus)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || echo "helm install failed (bonus steps will need it)"
fi

install_shell_aliases   # kubectl aliases + completion for the attendee's terminal

# Resolve the scenario's assets/ robustly — see the CAPD setup script for the
# full rationale. Some labs run this script from a different working directory,
# so $0 is NOT next to assets/; fall back accordingly.
SCENARIO="5spot-ctf-k0smotron"
WORKSHOP_REPO_URL="${WORKSHOP_REPO_URL:-https://github.com/firestoned/5-spot-workshop.git}"
WORKDIR="$HOME/5spot-workshop"; mkdir -p "$WORKDIR"
LOCAL_ASSETS="$(dirname "$0")/assets"
if [ -d "$LOCAL_ASSETS" ]; then
  cp -r "$LOCAL_ASSETS/." "$WORKDIR/"
fi
if [ ! -f "$WORKDIR/workload-cluster-k0smotron.yaml" ]; then
  echo "==> Assets not staged locally — fetching from $WORKSHOP_REPO_URL"
  tmp="$(mktemp -d)"
  git clone --depth 1 "$WORKSHOP_REPO_URL" "$tmp" >/dev/null 2>&1 \
    && cp -r "$tmp/workshop/$SCENARIO/assets/." "$WORKDIR/"
  rm -rf "$tmp"
fi
for need in workload-cluster-k0smotron.yaml scheduledmachine-k0smotron.yaml; do
  [ -f "$WORKDIR/$need" ] || { echo "✗ required manifest '$need' not found in $WORKDIR — check the index.json 'assets' block or WORKSHOP_REPO_URL"; exit 1; }
done
if git -C "$HOME/5-spot" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$HOME/5-spot" fetch --depth 1 origin && git -C "$HOME/5-spot" reset --hard origin/HEAD 2>/dev/null || true
else
  # Not a git repo (missing, empty, or a leftover dir) — start clean.
  rm -rf "$HOME/5-spot"
  git clone --depth 1 https://github.com/finos/5-spot.git $HOME/5-spot
fi

# ---- Management cluster -----------------------------------------------------
echo "==> Creating kind management cluster"
kind create cluster --name 5spot-mgmt
kubectl cluster-info --context "$MGMT"

echo "==> Installing cert-manager (k0smotron dependency)"
kubectl --context "$MGMT" apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
kubectl --context "$MGMT" wait --for=condition=Available --timeout=300s -n cert-manager deploy --all

echo "==> clusterctl init: CAPI core + k0smotron (bootstrap/control-plane/infra)"
clusterctl init \
  --bootstrap k0sproject-k0smotron \
  --control-plane k0sproject-k0smotron \
  --infrastructure k0sproject-k0smotron
for ns in capi-system; do
  kubectl wait --for=condition=Available --timeout=300s -n "$ns" deploy --all || true
done

# ---- 5-Spot controller (pull published image) ------------------------------
echo "==> Loading 5-Spot controller ${FIVESPOT_IMAGE}"
docker pull "$FIVESPOT_IMAGE"; kind load docker-image "$FIVESPOT_IMAGE" --name 5spot-mgmt
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/crds/
# Create the namespace first and wait for it to register. A single recursive apply
# can submit namespaced objects (configmap/deployment) before the freshly created
# namespace has propagated, failing with "namespaces 5spot-system not found".
kubectl --context "$MGMT" create namespace 5spot-system --dry-run=client -o yaml | kubectl --context "$MGMT" apply -f -
kubectl --context "$MGMT" wait --for=jsonpath='{.status.phase}'=Active ns/5spot-system --timeout=30s
kubectl --context "$MGMT" apply -R -f $HOME/5-spot/deploy/deployment/
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicy.yaml || true
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicybinding.yaml || true
kubectl --context "$MGMT" -n 5spot-system set image deployment/5spot-controller "controller=${FIVESPOT_IMAGE}"
# A single kind node is CPU-tight; the upstream manifest's CPU *request*
# is sized for a roomier cluster, so the pod fails to schedule ("Insufficient cpu").
# Requests (not limits) drive scheduling — shrink the request so it fits anywhere.
kubectl --context "$MGMT" -n 5spot-system patch deployment/5spot-controller --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"controller","resources":{"requests":{"cpu":"10m","memory":"64Mi"}}}]}}}}' || true
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/5spot-controller --timeout=180s

# ---- SSH key from mgmt -> remote node (the RemoteMachine target) ------------
echo "==> Generating SSH key and authorizing it on ${REMOTE_NODE_HOST}"
ssh-keygen -t ed25519 -N "" -f $HOME/remote_key <<<y >/dev/null 2>&1 || true
REMOTE_IP="$(getent hosts "$REMOTE_NODE_HOST" | awk '{print $1}')"; REMOTE_IP="${REMOTE_IP:-$REMOTE_NODE_HOST}"
# Best-effort: push the pubkey to the remote node (multi-node labs typically allow root SSH between nodes).
ssh -o StrictHostKeyChecking=no "root@${REMOTE_IP}" \
  "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < $HOME/remote_key.pub || \
  echo "    (could not auto-authorize; do it manually for your environment)"

kubectl --context "$MGMT" create secret generic remote-ssh-key \
  --from-file=value=$HOME/remote_key -n default --dry-run=client -o yaml | kubectl --context "$MGMT" apply -f -

# ---- Hosted workload cluster (control plane runs as pods; no worker yet) ----
echo "==> Creating hosted workload control plane (K0smotronControlPlane + RemoteCluster)"
kubectl --context "$MGMT" apply -f "$WORKDIR/workload-cluster-k0smotron.yaml"
kubectl --context "$MGMT" wait --for=condition=ControlPlaneInitialized cluster/dev-cluster --timeout=600s || \
  echo "    (control plane still initializing — check 'kubectl get k0smotroncontrolplane')"

echo "==> Fetching workload kubeconfig"
clusterctl get kubeconfig dev-cluster > $HOME/dev-cluster.kubeconfig || true
cp $HOME/dev-cluster.kubeconfig "$WORKDIR/dev-cluster.kubeconfig" 2>/dev/null || true

# ---- Template the remote IP into the ScheduledMachine (not applied yet) -----
sed -i "s/REMOTE_NODE_IP/${REMOTE_IP}/g" "$WORKDIR/scheduledmachine-k0smotron.yaml"
echo "==> RemoteMachine address set to ${REMOTE_IP}. ScheduledMachine NOT applied (that's Flag 1)."

echo "==> PRE-BAKE COMPLETE $(date -u). Apply the ScheduledMachine to capture Flag 1."
echo
echo "👉 Load the kubectl shortcuts in THIS shell now:  exec bash"
echo "   (then: k get nodes · ksm · kmgmt get pods -A · kwl get nodes)"
