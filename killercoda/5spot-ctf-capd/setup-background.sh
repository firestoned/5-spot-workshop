#!/usr/bin/env bash
# =============================================================================
# 5-Spot CTF — Easy tier pre-bake (Killercoda background script)
#
# Brings the environment up to "workload control-plane Ready + CNI installed"
# so the attendee starts at the fun part (apply a ScheduledMachine).
#
# ⚠️  RESOURCE SMOKE-TEST REQUIRED. kind + CAPD spins ~4 Docker containers. Run
#     this on a free Killercoda env once and confirm it finishes inside the
#     session/RAM budget. If not, move Easy to a pre-baked VM image or Codespaces.
#
# Mirrors finos/5-spot examples/workshop Parts 1–2. All version pins live here.
# =============================================================================
set -euo pipefail
LOGFILE="$( [ -w /opt ] && echo /opt/5spot-setup.log || echo /tmp/5spot-setup.log )"
exec > >(tee -a "$LOGFILE") 2>&1
echo "==> 5-Spot CTF pre-bake starting $(date -u)"

# ---- Version pins (the footguns) -------------------------------------------
KIND_NODE_IMAGE="kindest/node:v1.31.0"     # must match clusterctl-served version
CLUSTERCTL_VERSION="v1.9.5"                  # v1.9.x still serves cluster.x-k8s.io/v1beta1
FIVESPOT_IMAGE="ghcr.io/finos/5-spot:v0.2.2" # CONFIRM exact published tag
FIVESPOT_REF="${FIVESPOT_IMAGE##*:}"        # clone deploy/ manifests at the SAME tag — main has moved the CRD to v1beta1 while v0.2.2 serves v1alpha1
CALICO_VERSION="v3.28.0"
MGMT="kind-5spot-mgmt"

# ---- Tooling ---------------------------------------------------------------
# On Killercoda (Linux) we install the pinned CLIs into /usr/local/bin. On a
# facilitator's Mac the bootstrap (scripts/5-spot-bootstrap.sh) has already
# installed darwin/arm64 builds — skip the Linux downloads, which can't write
# the root-owned /usr/local/bin (curl error 23) and would clobber working tools.
if [ "$(uname -s)" = "Linux" ]; then
  echo "==> Installing kind, kubectl, clusterctl"
  curl -sSLo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
  chmod +x /usr/local/bin/kind
  curl -sSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
  chmod +x /usr/local/bin/kubectl
  curl -sSLo /usr/local/bin/clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64"
  chmod +x /usr/local/bin/clusterctl

  echo "==> Installing helm (Flux bonus + CoCo bonus)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || echo "helm install failed (bonus steps will need it)"
else
  echo "==> Non-Linux host — using pre-installed CLIs from scripts/5-spot-bootstrap.sh"
  for t in kind kubectl clusterctl; do
    command -v "$t" >/dev/null || { echo "✗ $t not found — run scripts/5-spot-bootstrap.sh --env-tier kind first"; exit 1; }
  done
fi

# ---- Source manifests (vendored copies live alongside this script) ---------
ASSETS="$(cd "$(dirname "$0")/assets" && pwd)"
WORKDIR="$HOME/5spot-workshop"
mkdir -p "$WORKDIR" && cp -r "$ASSETS/." "$WORKDIR/"
echo "==> Cloning 5-spot @ ${FIVESPOT_REF} for deploy/ manifests (must match the controller image tag)"
if git -C "$HOME/5-spot" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$HOME/5-spot" fetch --depth 1 origin tag "$FIVESPOT_REF"
  git -C "$HOME/5-spot" checkout -q "$FIVESPOT_REF"
else
  # Not a git repo (missing, empty, or a leftover dir) — start clean.
  rm -rf "$HOME/5-spot"
  git clone --depth 1 --branch "$FIVESPOT_REF" https://github.com/finos/5-spot.git $HOME/5-spot
fi

# ---- Part 1: management cluster + CAPI + CAPD ------------------------------
echo "==> Creating kind management cluster"
if kind get clusters 2>/dev/null | grep -qx 5spot-mgmt; then
  echo "    (cluster 5spot-mgmt already exists — reusing)"
else
  kind create cluster --config "$WORKDIR/kind-management.yaml"
fi
kubectl cluster-info --context "$MGMT"

echo "==> clusterctl init --infrastructure docker"
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure docker
for ns in capi-system capd-system capi-kubeadm-bootstrap-system capi-kubeadm-control-plane-system; do
  kubectl wait --for=condition=Available --timeout=300s -n "$ns" deploy --all
done

# ---- Part 1.3: 5-Spot controller (PULL the published image, don't build) ---
echo "==> Loading 5-Spot controller image ${FIVESPOT_IMAGE}"
docker pull "$FIVESPOT_IMAGE"
# Docker's containerd image store keeps the full multi-arch index locally. kind's
# `load docker-image` re-imports with --all-platforms and dies on the missing
# foreign-arch blobs ("content digest ... not found"). Save just this host's
# platform to an archive and load that instead; fall back to the direct load.
case "$(uname -m)" in aarch64|arm64) PLAT=linux/arm64;; *) PLAT=linux/amd64;; esac
if docker save --platform "$PLAT" "$FIVESPOT_IMAGE" -o /tmp/5spot-controller.tar 2>/dev/null; then
  kind load image-archive /tmp/5spot-controller.tar --name 5spot-mgmt
  rm -f /tmp/5spot-controller.tar
else
  kind load docker-image "$FIVESPOT_IMAGE" --name 5spot-mgmt
fi
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/crds/
# Create the namespace first and wait for it to register. A single recursive
# apply can submit namespaced objects (configmap/deployment) before the freshly
# created namespace has propagated, failing with "namespaces ... not found".
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/deployment/namespace.yaml
kubectl --context "$MGMT" wait --for=jsonpath='{.status.phase}'=Active ns/5spot-system --timeout=30s
kubectl --context "$MGMT" apply -R -f $HOME/5-spot/deploy/deployment/
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicy.yaml
kubectl --context "$MGMT" apply -f $HOME/5-spot/deploy/admission/validatingadmissionpolicybinding.yaml
kubectl --context "$MGMT" -n 5spot-system set image deployment/5spot-controller "controller=${FIVESPOT_IMAGE}"
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/5spot-controller --timeout=180s

# ---- Part 2: workload cluster + CNI ----------------------------------------
echo "==> Creating workload cluster dev-cluster"
kubectl --context "$MGMT" apply -f "$WORKDIR/workload-cluster.yaml"
kubectl --context "$MGMT" wait --for=condition=ControlPlaneInitialized cluster/dev-cluster --timeout=600s

echo "==> Fetching workload kubeconfig + installing Calico CNI"
clusterctl get kubeconfig dev-cluster > "$WORKDIR/dev-cluster.kubeconfig"
# CAPD writes the workload API server's Docker-internal IP (172.18.x) into the
# kubeconfig. That's reachable from a Linux host (Killercoda) but NOT from macOS,
# where colima/Docker only forwards the load-balancer's *published* port to
# localhost. Rewrite the endpoint to that port on non-Linux hosts.
if [ "$(uname -s)" != "Linux" ]; then
  LB_PORT="$(docker port dev-cluster-lb 6443/tcp 2>/dev/null | head -1 | sed 's/.*://')"
  if [ -n "$LB_PORT" ]; then
    sed -i.bak -E "s#server: https://.*:6443#server: https://127.0.0.1:${LB_PORT}#" "$WORKDIR/dev-cluster.kubeconfig"
    rm -f "$WORKDIR/dev-cluster.kubeconfig.bak"
    echo "    (rewrote workload API endpoint → https://127.0.0.1:${LB_PORT} for macOS/colima)"
  fi
fi
cp "$WORKDIR/dev-cluster.kubeconfig" $HOME/dev-cluster.kubeconfig   # well-known path for verifiers
kubectl --kubeconfig "$WORKDIR/dev-cluster.kubeconfig" apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "==> Pre-pulling worker node image so Flag 1 is fast"
docker pull "$KIND_NODE_IMAGE" || true
# Same containerd-store multi-arch caveat as the controller image — load a
# platform-scoped archive, fall back to the direct load. (CAPD creates workers
# from the host Docker image, so this is a warm-cache optimization, not required.)
if docker save --platform "$PLAT" "$KIND_NODE_IMAGE" -o /tmp/kind-node.tar 2>/dev/null; then
  kind load image-archive /tmp/kind-node.tar --name 5spot-mgmt || true
  rm -f /tmp/kind-node.tar
else
  kind load docker-image "$KIND_NODE_IMAGE" --name 5spot-mgmt || true
fi

echo "==> PRE-BAKE COMPLETE $(date -u). Workload control plane is Ready."
# Expect zero ScheduledMachines — creating the first one is Flag 1, not a setup step.
if kubectl --context "$MGMT" get sm -A 2>/dev/null | grep -q .; then
  kubectl --context "$MGMT" get sm -A
else
  echo "    No ScheduledMachines yet — apply one to capture Flag 1."
fi
