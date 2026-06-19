#!/usr/bin/env bash
# =============================================================================
# 5-Spot CTF — REAL tier pre-bake (k0s + k0smotron, RemoteMachine over SSH)
#
# Topology:
#   node01: kind management cluster (CAPI core + k0smotron providers + 5-Spot)
#           + a HOSTED workload control plane (K0smotronControlPlane).
#   node02: the SSH target a scheduled k0s worker (RemoteMachine) is provisioned onto.
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
REMOTE_NODE_HOST="${REMOTE_NODE_HOST:-node02}"  # Killercoda 2nd node; override locally

# ---- Tooling ---------------------------------------------------------------
echo "==> Installing kind, kubectl, clusterctl"
curl -sSLo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64; chmod +x /usr/local/bin/kind
curl -sSLo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl; chmod +x /usr/local/bin/kubectl
curl -sSLo /usr/local/bin/clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64"; chmod +x /usr/local/bin/clusterctl

echo "==> Installing helm (Flux bonus + CoCo bonus)"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || echo "helm install failed (bonus steps will need it)"

ASSETS="$(cd "$(dirname "$0")/assets" && pwd)"
WORKDIR="$HOME/5spot-workshop"; mkdir -p "$WORKDIR"; cp -r "$ASSETS/." "$WORKDIR/"
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
kubectl --context "$MGMT" apply -R -f $HOME/5-spot/deploy/deployment/
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicy.yaml || true
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicybinding.yaml || true
kubectl --context "$MGMT" -n 5spot-system set image deployment/5spot-controller "controller=${FIVESPOT_IMAGE}"
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/5spot-controller --timeout=180s

# ---- SSH key from mgmt -> remote node (the RemoteMachine target) ------------
echo "==> Generating SSH key and authorizing it on ${REMOTE_NODE_HOST}"
ssh-keygen -t ed25519 -N "" -f $HOME/remote_key <<<y >/dev/null 2>&1 || true
REMOTE_IP="$(getent hosts "$REMOTE_NODE_HOST" | awk '{print $1}')"; REMOTE_IP="${REMOTE_IP:-$REMOTE_NODE_HOST}"
# Best-effort: push the pubkey to the remote node (Killercoda nodes trust each other).
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
