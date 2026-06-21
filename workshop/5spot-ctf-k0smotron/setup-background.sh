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
# Modern k0smotron (v1.10.x) watches the CAPI Machine at cluster.x-k8s.io/v1beta2, so
# CAPI core MUST serve v1beta2 — that means the v1.11 line (v1beta2 GA'd there; it
# still serves v1beta1 for conversion). Stay on v1.11.x to match what k0smotron v1.10.8
# was built against (cluster-api@v1.11.x); v1.12/v1.13 risk dropping v1beta1 serving.
CLUSTERCTL_VERSION="${CLUSTERCTL_VERSION:-v1.11.11}"   # serves cluster.x-k8s.io v1beta2 AND v1beta1
K0SMOTRON_VERSION="${K0SMOTRON_VERSION:-v1.10.8}"      # latest 1.x; watches Machine v1beta2
# 5-Spot now discovers the served CAPI Machine version and creates the Machine at the
# version declared on bootstrapSpec.apiVersion (passthrough, PR #88) — so one image
# works on a v1beta2 cluster. Override FIVESPOT_IMAGE / FIVESPOT_REF for a different build.
FIVESPOT_IMAGE="${FIVESPOT_IMAGE:-ghcr.io/finos/5-spot:pr-96}"
# deploy/ manifests (CRD + RBAC + provider Deployments) must MATCH the controller image.
# The work merged to main (v1beta1 CRD #82, provider-ref schedule #87, CAPI passthrough
# #88, provider binaries, the idempotency / child-client-kubeconfig fixes), and the image
# is built from main — so pin the manifests to `main` too (the tag "main-2026-06-24" is
# not a git ref). v0.2.2 would reject the v1beta1 ScheduledMachine in assets/.
FIVESPOT_REF="${FIVESPOT_REF:-main}"
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
# clusterctl is SPECIAL: its version dictates which CAPI core (and thus which served
# Cluster/Machine API versions) `clusterctl init` installs. v1beta2 — required by
# modern k0smotron — needs CAPI >= v1.11, i.e. clusterctl >= v1.11. The MiniLAN
# playground ships an OLD clusterctl (v1.9.x), and install-only-if-missing would keep
# it and silently install a v1beta1-only CAPI v1.10. Force the pinned version on any
# mismatch (not just when missing), or the whole v1beta2 stack is undermined.
if ! clusterctl version 2>/dev/null | grep -q "GitVersion:\"${CLUSTERCTL_VERSION}\""; then
  install_bin clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-${ARCH}"
  hash -r 2>/dev/null || true
fi
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
for need in workload-cluster-k0smotron.yaml scheduledmachine-k0smotron.yaml kind-management-k0smotron.yaml; do
  [ -f "$WORKDIR/$need" ] || { echo "✗ required manifest '$need' not found in $WORKDIR — check the index.json 'assets' block or WORKSHOP_REPO_URL"; exit 1; }
done
if git -C "$HOME/5-spot" rev-parse --git-dir >/dev/null 2>&1; then
  # Fetch the ref generically so this works for a branch (e.g. a PR branch) OR a tag.
  git -C "$HOME/5-spot" fetch --depth 1 origin "$FIVESPOT_REF" && git -C "$HOME/5-spot" checkout -q FETCH_HEAD
else
  # Not a git repo (missing, empty, or a leftover dir) — start clean.
  rm -rf "$HOME/5-spot"
  git clone --depth 1 --branch "$FIVESPOT_REF" https://github.com/finos/5-spot.git $HOME/5-spot
fi

# ---- Raise inotify limits (kind multi-node footgun) ------------------------
# Each kind/k0s node's kubelet/cAdvisor needs inotify instances + watches. On
# hosts with low defaults (nested playgrounds like iximiuz, some CI) a node's
# kubelet crash-loops with "inotify_init: too many open files". Raise them
# (best-effort; needs privileges, which Killercoda/iximiuz have).
echo "==> Raising inotify limits for kind (fs.inotify.max_user_{instances,watches})"
sysctl -w fs.inotify.max_user_instances=8192  >/dev/null 2>&1 || true
sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null 2>&1 || true

# ---- Management cluster -----------------------------------------------------
echo "==> Creating kind management cluster (publishing hosted control-plane NodePorts)"
# Use the config that maps the hosted control plane's NodePorts (30443/30132) onto
# node-01's host, so the remote worker on the MiniLAN can reach them. Falls back to a
# bare cluster if the config asset is somehow missing (control plane still comes up,
# but Flag 1's remote worker won't be able to join).
if [ -f "$WORKDIR/kind-management-k0smotron.yaml" ]; then
  kind create cluster --name 5spot-mgmt --image "$KIND_NODE_IMAGE" --config "$WORKDIR/kind-management-k0smotron.yaml"
else
  echo "    ⚠ kind-management-k0smotron.yaml missing — creating without NodePort mappings"
  kind create cluster --name 5spot-mgmt --image "$KIND_NODE_IMAGE"
fi
kubectl cluster-info --context "$MGMT"

echo "==> Installing cert-manager (k0smotron dependency)"
kubectl --context "$MGMT" apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
kubectl --context "$MGMT" wait --for=condition=Available --timeout=300s -n cert-manager deploy --all \
  || echo "    (cert-manager slow to become Available — continuing; k0smotron may retry)"

echo "==> clusterctl init: CAPI core ${CLUSTERCTL_VERSION} + k0smotron ${K0SMOTRON_VERSION} (v1beta2 stack)"
# Pin BOTH CAPI core and the k0smotron providers for reproducibility. CAPI v1.11
# serves v1beta2 (which k0smotron v1.10.8 watches) AND v1beta1 (which 5-Spot's
# bootstrapSpec passthrough may create — conversion bridges the two). Bump as a pair.
clusterctl init \
  --core "cluster-api:${CLUSTERCTL_VERSION}" \
  --bootstrap "k0sproject-k0smotron:${K0SMOTRON_VERSION}" \
  --control-plane "k0sproject-k0smotron:${K0SMOTRON_VERSION}" \
  --infrastructure "k0sproject-k0smotron:${K0SMOTRON_VERSION}"
# Wait for CAPI core AND the k0smotron providers — the k0smotron control-plane /
# bootstrap controllers serve validating webhooks (cert issued by cert-manager), and
# applying the workload cluster before they're Ready fails with the webhook
# "connection refused". Their pods block on the cert mount, so Available ⇒ webhook up.
for ns in capi-system k0smotron; do
  kubectl wait --for=condition=Available --timeout=300s -n "$ns" deploy --all || true
done

# ---- 5-Spot controller (pull published image) ------------------------------
echo "==> Loading 5-Spot controller ${FIVESPOT_IMAGE}"
docker pull "$FIVESPOT_IMAGE"
# Docker's containerd image store keeps a multi-arch index; `kind load docker-image`
# re-imports with --all-platforms and dies on missing foreign-arch blobs
# ("content digest … not found"). Save just this host's platform to an archive and
# load that; fall back to a direct load; finally let the node pull from ghcr.
case "$(uname -m)" in aarch64|arm64) PLAT=linux/arm64;; *) PLAT=linux/amd64;; esac
loaded=false
if docker save --platform "$PLAT" "$FIVESPOT_IMAGE" -o /tmp/5spot-controller.tar 2>/dev/null; then
  if kind load image-archive /tmp/5spot-controller.tar --name 5spot-mgmt 2>/dev/null; then loaded=true; fi
  rm -f /tmp/5spot-controller.tar
fi
if ! $loaded && kind load docker-image "$FIVESPOT_IMAGE" --name 5spot-mgmt 2>/dev/null; then loaded=true; fi
$loaded || echo "  ⚠ could not preload ${FIVESPOT_IMAGE} into kind — the node will pull it from ghcr"
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
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/5spot-controller --timeout=180s \
  || echo "    (5-Spot controller slow to roll out — continuing; check 'kmgmt -n 5spot-system get pods')"

# ---- Spot-schedule provider (ADR 0009): TimeBasedSpotSchedule controller -----
# The v1beta1 ScheduledMachine references a TimeBasedSpotSchedule provider object whose
# status.active is the machine's active/inactive verdict. That provider is a SEPARATE
# controller (not bundled in deploy/deployment/) — without it the schedule never goes
# active and no worker is ever created. Its shipped manifest pins a stale image, so
# override to our build (the `spot-schedule-time-based` binary ships in the same image).
echo "==> Deploying the TimeBasedSpotSchedule schedule provider"
kubectl --context "$MGMT" apply -k "$HOME/5-spot/deploy/spot-schedule-providers/time-based/"
kubectl --context "$MGMT" -n 5spot-system set image deployment/spot-schedule-time-based "provider=${FIVESPOT_IMAGE}"
kubectl --context "$MGMT" -n 5spot-system patch deployment/spot-schedule-time-based --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"provider","resources":{"requests":{"cpu":"10m","memory":"32Mi"}}}]}}}}' || true
kubectl --context "$MGMT" -n 5spot-system rollout status deployment/spot-schedule-time-based --timeout=120s \
  || echo "    (schedule provider slow to roll out — the ScheduledMachine won't activate until it is up)"

# ---- SSH key from mgmt -> remote node (the RemoteMachine target) ------------
# The k0smotron RemoteMachine controller SSHes into the remote node AS ROOT and runs
# `k0s install worker` (writes /etc/systemd, /etc/k0s) — its `useSudo` does NOT elevate
# those commands, so the controller must reach the remote as real root.
REMOTE_IP="$(getent hosts "$REMOTE_NODE_HOST" | awk '{print $1}')"; REMOTE_IP="${REMOTE_IP:-$REMOTE_NODE_HOST}"
# node-01's OWN LAN IP — the address the remote worker reaches the hosted control plane
# at. Derive it as the source IP node-01 uses to reach the remote node (most robust on
# multi-homed hosts: node-01 also has a docker-bridge IP we must NOT advertise).
NODE01_IP="$(ip -4 route get "$REMOTE_IP" 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}' | head -1)"
NODE01_IP="${NODE01_IP:-$(hostname -I 2>/dev/null | awk '{print $1}')}"
echo "    node-01 LAN IP = ${NODE01_IP} (control-plane externalAddress); remote = ${REMOTE_IP}"
# CRITICAL: BatchMode=yes + ConnectTimeout so SSH can NEVER hang on a prompt.
SSHOPTS="-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10"
REMOTE_LOGIN_USER="${REMOTE_LOGIN_USER:-laborant}"   # fallback user with inter-node trust

# Resolve the private key the RemoteMachine will present as root@remote:
#   - iximiuz MiniLAN: root<->root is PRE-TRUSTED via a managed key, but the nodes'
#     authorized_keys are READ-ONLY — we cannot add a key we generate. So reuse the
#     host's existing root key (already authorized on the remote root).
#   - Killercoda / bare metal: no pre-shared key — generate one and authorize it for root.
HOST_ROOT_KEY="${HOST_ROOT_KEY:-$HOME/.ssh/id_ed25519}"
authorize_remote_key() {
  local pub; pub="$(cat "$HOME/remote_key.pub")"
  printf '%s\n' "$pub" | ssh $SSHOPTS "root@${REMOTE_IP}" \
    "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" 2>/dev/null && return 0
  if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" = 0 ] && id "${REMOTE_LOGIN_USER}" >/dev/null 2>&1; then
    printf '%s\n' "$pub" | sudo -u "${REMOTE_LOGIN_USER}" -H ssh $SSHOPTS "${REMOTE_LOGIN_USER}@${REMOTE_IP}" \
      "sudo mkdir -p /root/.ssh && sudo tee -a /root/.ssh/authorized_keys >/dev/null" 2>/dev/null && return 0
  fi
  printf '%s\n' "$pub" | ssh $SSHOPTS "${REMOTE_LOGIN_USER}@${REMOTE_IP}" \
    "sudo mkdir -p /root/.ssh && sudo tee -a /root/.ssh/authorized_keys >/dev/null" 2>/dev/null && return 0
  return 1
}

if [ -r "$HOST_ROOT_KEY" ] && ssh -i "$HOST_ROOT_KEY" $SSHOPTS "root@${REMOTE_IP}" true 2>/dev/null; then
  echo "==> root@${REMOTE_IP} is pre-trusted — reusing the host's existing root key (managed inter-node SSH)"
  cp "$HOST_ROOT_KEY" "$HOME/remote_key" && chmod 600 "$HOME/remote_key"
else
  echo "==> Generating an SSH key and authorizing it for root@${REMOTE_NODE_HOST}"
  ssh-keygen -t ed25519 -N "" -f "$HOME/remote_key" <<<y >/dev/null 2>&1 || true
  if authorize_remote_key; then
    echo "    authorized our key for root@${REMOTE_IP}"
  else
    echo "    ⚠ could not establish root SSH to ${REMOTE_IP} — Flag 1 (remote worker) will not provision."
    echo "      Wire a root-trusted key manually — see docs/iximiuz-setup.md §4."
  fi
fi

kubectl --context "$MGMT" create secret generic remote-ssh-key \
  --from-file=value=$HOME/remote_key -n default --dry-run=client -o yaml | kubectl --context "$MGMT" apply -f -

# ---- Hosted workload cluster (control plane runs as pods; no worker yet) ----
# Point the control plane's advertised endpoint at node-01's LAN IP (reachable by the
# remote worker) instead of the kind-internal docker IP k0smotron would auto-detect.
sed -i "s/NODE01_IP/${NODE01_IP}/g" "$WORKDIR/workload-cluster-k0smotron.yaml"
echo "==> Creating hosted workload control plane (K0smotronControlPlane + RemoteCluster)"
# Retry the apply: even after the controller deploy is Available, the validating
# webhook can briefly refuse connections while cert-manager's CA bundle is injected
# into the ValidatingWebhookConfiguration and the endpoint registers. Retry only on
# webhook/transient errors; fail fast on a genuine manifest error.
wl_applied=false
for i in $(seq 1 30); do
  if kubectl --context "$MGMT" apply -f "$WORKDIR/workload-cluster-k0smotron.yaml" 2>/tmp/wl-apply.err; then
    wl_applied=true; break
  fi
  if grep -qiE "webhook|connection refused|no endpoints available|InternalError|timeout" /tmp/wl-apply.err; then
    echo "    waiting for k0smotron webhook to accept the workload cluster (attempt $i)…"; sleep 10
  else
    cat /tmp/wl-apply.err; break
  fi
done
$wl_applied || { echo "✗ failed to create the workload control plane:"; cat /tmp/wl-apply.err; exit 1; }
kubectl --context "$MGMT" wait --for=condition=ControlPlaneInitialized cluster/dev-cluster --timeout=600s || \
  echo "    (control plane still initializing — check 'kubectl get k0smotroncontrolplane')"

echo "==> Fetching workload kubeconfig"
clusterctl get kubeconfig dev-cluster > $HOME/dev-cluster.kubeconfig || true
cp $HOME/dev-cluster.kubeconfig "$WORKDIR/dev-cluster.kubeconfig" 2>/dev/null || true

# ---- 5-Spot child kubeconfig (DIRECT mTLS to the hosted CP) + egress for its port ----
# 5-Spot runs as a pod in the kind mgmt cluster and reaches the HOSTED k0s control plane
# DIRECTLY to taint/drain the worker Node (no proxy). Two things this scenario needs:
#   1. The child kubeconfig — the stock workload kubeconfig retargeted to the in-cluster
#      NodePort service endpoint (no hairpin); its REAL CA + client cert are kept intact
#      (that client cert is 5-Spot's mTLS identity). No proxy, no insecure-skip-tls-verify.
#   2. NetworkPolicy egress — the 5-Spot controller's bundled egress policy permits only the
#      management apiserver (port 6443) + DNS. A k0smotron hosted CP serves on its NodePort
#      apiPort (default 30443), so WITHOUT allowing 30443 the child connection is silently
#      dropped at the network layer ("client error (Connect) -> deadline has elapsed") and
#      the taint/drain never happens. We add an ADDITIVE NetworkPolicy so this works even on
#      a 5-Spot build whose bundled policy predates the 30443 allowance.
#   (Both the missing SSA apiVersion/kind on the taint patch AND the 30443 egress are fixed
#    in the 5-Spot image — this is the matching workshop side. Earlier proxy/rustls
#    workarounds were misdiagnoses; the connection was simply firewalled.)
echo "==> Building 5-Spot child kubeconfig (direct mTLS, in-cluster :30443) + egress NetworkPolicy"
KMC_SVC="$(kubectl --context "$MGMT" -n default get svc -o name 2>/dev/null | sed 's#service/##' | grep -E '^kmc-.*-nodeport$' | head -1)"
KMC_ENDPOINT="${KMC_SVC:+https://${KMC_SVC}.default.svc:30443}"
KMC_ENDPOINT="${KMC_ENDPOINT:-https://${NODE01_IP}:30443}"   # fall back to the LAN endpoint
if clusterctl get kubeconfig dev-cluster > "$HOME/dev-cluster-5spot.kubeconfig" 2>/dev/null; then
  CL="$(KUBECONFIG=$HOME/dev-cluster-5spot.kubeconfig kubectl config view -o jsonpath='{.clusters[0].name}' 2>/dev/null)"
  # Retarget the server ONLY — keep certificate-authority-data and the client cert/key.
  KUBECONFIG=$HOME/dev-cluster-5spot.kubeconfig kubectl config set-cluster "$CL" --server="$KMC_ENDPOINT" >/dev/null 2>&1 || true
  kubectl --context "$MGMT" create secret generic dev-cluster-kubeconfig-5spot \
    --from-file=value="$HOME/dev-cluster-5spot.kubeconfig" -n default --dry-run=client -o yaml | kubectl --context "$MGMT" apply -f -
  echo "    5-Spot will reach the hosted control plane DIRECTLY at ${KMC_ENDPOINT} (mTLS, real CA)"
else
  echo "    ⚠ could not build the 5-Spot child kubeconfig — taints/drains (Flags 2-3) may fail"
fi
# Additive egress NetworkPolicy: permit the controller to reach the hosted CP's apiPort (30443).
kubectl --context "$MGMT" apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: 5spot-controller-k0smotron-egress
  namespace: 5spot-system
spec:
  podSelector:
    matchLabels:
      app: 5spot-controller
  policyTypes: [Egress]
  egress:
    - ports:
        - protocol: TCP
          port: 30443
EOF
echo "    egress NetworkPolicy allows the controller -> hosted CP on :30443"

# ---- Template the remote IP into the ScheduledMachine (not applied yet) -----
sed -i "s/REMOTE_NODE_IP/${REMOTE_IP}/g" "$WORKDIR/scheduledmachine-k0smotron.yaml"
echo "==> RemoteMachine address set to ${REMOTE_IP}. ScheduledMachine NOT applied (that's Flag 1)."

echo "==> PRE-BAKE COMPLETE $(date -u). Apply the ScheduledMachine to capture Flag 1."
echo
echo "👉 Load the kubectl shortcuts in THIS shell now:  exec bash"
echo "   (then: k get nodes · ksm · kmgmt get pods -A · kwl get nodes)"
