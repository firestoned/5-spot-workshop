#!/usr/bin/env bash
# =============================================================================
# 5-Spot CTF — CAPD pre-bake (shared: iximiuz init task, local kind, Codespaces)
#
# Brings the environment up to "workload control-plane Ready + CNI installed"
# so the attendee starts at the fun part (apply a ScheduledMachine).
#
# ⚠️  RESOURCE SMOKE-TEST REQUIRED. kind + CAPD spins ~4 Docker containers. Run
#     this on the target playground/host once and confirm it finishes inside the
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
# On a Linux lab host we install the pinned CLIs into /usr/local/bin. On a
# facilitator's Mac the bootstrap (scripts/5-spot-bootstrap.sh) has already
# installed darwin/arm64 builds — skip the Linux downloads, which can't write
# the root-owned /usr/local/bin (curl error 23) and would clobber working tools.
if [ "$(uname -s)" = "Linux" ]; then
  # Install the pinned CLIs only if MISSING. A browser-lab host runs this script
  # standalone as root with nothing pre-installed; Codespaces/local already have them via the
  # devcontainer/bootstrap AND run as a non-root user who can't write the root-owned
  # /usr/local/bin (curl error 23). So: skip what's present, and sudo when needed.
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
else
  echo "==> Non-Linux host — using pre-installed CLIs from scripts/5-spot-bootstrap.sh"
  for t in kind kubectl clusterctl; do
    command -v "$t" >/dev/null || { echo "✗ $t not found — run scripts/5-spot-bootstrap.sh --env-tier kind first"; exit 1; }
  done
fi

# ---- Source manifests ------------------------------------------------------
# The scenario's manifests live in assets/. Resolve them robustly, because where
# they are depends on how this script was launched:
#   1) next to this script        — local `make kind` ($0 is in the scenario dir)
#   2) staged into $WORKDIR        — a lab host that pre-stages assets there
#   3) fetched from the workshop repo — fallback (when $0 is NOT next to assets/,
#      e.g. a lab that runs this script from a different working directory)
SCENARIO="5spot-ctf-capd"
WORKSHOP_REPO_URL="${WORKSHOP_REPO_URL:-https://github.com/firestoned/5-spot-workshop.git}"
WORKDIR="$HOME/5spot-workshop"; mkdir -p "$WORKDIR"
LOCAL_ASSETS="$(dirname "$0")/assets"
if [ -d "$LOCAL_ASSETS" ]; then
  cp -r "$LOCAL_ASSETS/." "$WORKDIR/"
fi
if [ ! -f "$WORKDIR/kind-management.yaml" ]; then
  echo "==> Assets not staged locally — fetching from $WORKSHOP_REPO_URL"
  tmp="$(mktemp -d)"
  git clone --depth 1 "$WORKSHOP_REPO_URL" "$tmp" >/dev/null 2>&1 \
    && cp -r "$tmp/workshop/$SCENARIO/assets/." "$WORKDIR/"
  rm -rf "$tmp"
fi
for need in kind-management.yaml workload-cluster.yaml; do
  [ -f "$WORKDIR/$need" ] || { echo "✗ required manifest '$need' not found in $WORKDIR — check the index.json 'assets' block or WORKSHOP_REPO_URL"; exit 1; }
done
echo "==> Cloning 5-spot @ ${FIVESPOT_REF} for deploy/ manifests (must match the controller image tag)"
if git -C "$HOME/5-spot" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$HOME/5-spot" fetch --depth 1 origin tag "$FIVESPOT_REF"
  git -C "$HOME/5-spot" checkout -q "$FIVESPOT_REF"
else
  # Not a git repo (missing, empty, or a leftover dir) — start clean.
  rm -rf "$HOME/5-spot"
  git clone --depth 1 --branch "$FIVESPOT_REF" https://github.com/finos/5-spot.git $HOME/5-spot
fi

# ---- Raise inotify limits (kind multi-node footgun) ------------------------
# kind + CAPD run several node containers (mgmt control-plane + workload
# control-plane + the scheduled worker); each node's kubelet/cAdvisor needs
# inotify instances + watches. On hosts with low defaults — nested playgrounds
# like iximiuz, some CI — the worker kubelet crash-loops with
# "inotify_init: too many open files" and the node never joins. Raise them
# (best-effort; needs privileges, which Killercoda/iximiuz/Codespaces have).
echo "==> Raising inotify limits for kind (fs.inotify.max_user_{instances,watches})"
sysctl -w fs.inotify.max_user_instances=8192  >/dev/null 2>&1 || true
sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null 2>&1 || true

# ---- Part 1: management cluster + CAPI + CAPD ------------------------------
echo "==> Creating kind management cluster"
if kind get clusters 2>/dev/null | grep -qx 5spot-mgmt; then
  echo "    (cluster 5spot-mgmt already exists — reusing)"
else
  kind create cluster --config "$WORKDIR/kind-management.yaml"
fi
kubectl cluster-info --context "$MGMT"

echo "==> clusterctl init (CAPI providers PINNED to ${CLUSTERCTL_VERSION})"
export CLUSTER_TOPOLOGY=true
# Pin the PROVIDER versions, not just the clusterctl binary. `clusterctl init`
# fetches the LATEST providers by default — that pulls CAPI v1.10.x, which changes
# cluster.x-k8s.io/v1beta1 handling and leaves the 5-Spot-created worker Machine
# stuck in Pending (Flag 1/2 never go Ready). 5-Spot v0.2.2 emits v1beta1, so we
# must hold the providers on the v1.9.x line.
clusterctl init \
  --core "cluster-api:${CLUSTERCTL_VERSION}" \
  --bootstrap "kubeadm:${CLUSTERCTL_VERSION}" \
  --control-plane "kubeadm:${CLUSTERCTL_VERSION}" \
  --infrastructure "docker:${CLUSTERCTL_VERSION}"
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
loaded=false
if docker save --platform "$PLAT" "$FIVESPOT_IMAGE" -o /tmp/5spot-controller.tar 2>/dev/null; then
  if kind load image-archive /tmp/5spot-controller.tar --name 5spot-mgmt 2>/dev/null; then loaded=true; fi
  rm -f /tmp/5spot-controller.tar
fi
# Fallback: direct load. (macOS/colima's containerd image store sometimes makes
# the archive import fail with "mismatched image rootfs and manifest layers".)
if ! $loaded && kind load docker-image "$FIVESPOT_IMAGE" --name 5spot-mgmt 2>/dev/null; then loaded=true; fi
# Last resort: don't abort — the image is public, so the node pulls it from ghcr
# on deploy (imagePullPolicy IfNotPresent). The rollout wait below still gates.
$loaded || echo "  ⚠ could not preload ${FIVESPOT_IMAGE} into kind (macOS/colima multi-arch quirk) — the node will pull it from ghcr"
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
# A single kind node is CPU-tight; the upstream manifest's CPU *request*
# is sized for a roomier cluster, so the pod fails to schedule ("Insufficient cpu").
# Requests (not limits) drive scheduling — shrink the request so it fits anywhere.
kubectl --context "$MGMT" -n 5spot-system patch deployment/5spot-controller --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"controller","resources":{"requests":{"cpu":"10m","memory":"64Mi"}}}]}}}}' || true
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/5spot-controller --timeout=180s

# ---- Part 1.4: machine-version-defaulter (5-Spot v0.2.2 + CAPI v1.9.x gap) --
# 5-Spot doesn't set Machine.spec.version and the ScheduledMachine CRD has no field
# for it, so the kubeadm worker bootstrap fails ("failed to parse kubernetes
# version") and the worker hangs in Pending. This tiny controller stamps the
# version on any Machine missing it, which unblocks bootstrap. See the manifest.
echo "==> Deploying machine-version-defaulter (kubeadm worker-bootstrap fix)"
kubectl --context "$MGMT" apply -f "$WORKDIR/machine-version-defaulter.yaml"
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/machine-version-defaulter --timeout=120s

# ---- Part 2: workload cluster + CNI ----------------------------------------
echo "==> Creating workload cluster dev-cluster"
kubectl --context "$MGMT" apply -f "$WORKDIR/workload-cluster.yaml"
kubectl --context "$MGMT" wait --for=condition=ControlPlaneInitialized cluster/dev-cluster --timeout=600s

echo "==> Fetching workload kubeconfig + installing Calico CNI"
clusterctl get kubeconfig dev-cluster > "$WORKDIR/dev-cluster.kubeconfig"
# CAPD writes the workload API server's Docker-internal IP (172.18.x) into the
# kubeconfig. That's reachable from a Linux lab host but NOT from macOS,
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

echo
echo "👉 Load the kubectl shortcuts in THIS shell now:  exec bash"
echo "   (then: k get nodes · ksm · kmgmt get pods -A · kwl get nodes)"
