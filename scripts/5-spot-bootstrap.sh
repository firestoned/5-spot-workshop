#!/usr/bin/env bash
# =============================================================================
# 5-spot-bootstrap.sh — make sure you have every tool your chosen tier needs.
#
#   ./scripts/5-spot-bootstrap.sh --env-tier kind          # local kind (Medium)
#   ./scripts/5-spot-bootstrap.sh --env-tier hard          # full local k0smotron (Hard)
#   ./scripts/5-spot-bootstrap.sh --env-tier codespaces    # verify a Codespace
#   ./scripts/5-spot-bootstrap.sh --env-tier kind --check-only   # report, don't install
#
# Supports macOS (Homebrew) and Linux (amd64/arm64). Windows users: use the
# codespaces tier or the iximiuz browser lab — see docs/quickstart-tiers.md.
# Docs: https://5spot.finos.org/installation/prerequisites/
# =============================================================================
set -uo pipefail

# ---- pins (keep in sync with workshop/*/setup-background.sh) --------------
KUBECTL_VERSION="v1.31.0"
KIND_VERSION="v0.24.0"
CLUSTERCTL_VERSION="v1.9.5"     # v1.9.x serves cluster.x-k8s.io/v1beta1 (5-Spot needs this)
COLIMA_MIN_MEM_GB=8

TIER=""; CHECK_ONLY=false
while [ $# -gt 0 ]; do
  case "$1" in
    --env-tier) TIER="${2:-}"; shift 2;;
    --check-only) CHECK_ONLY=true; shift;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1 (try --help)"; exit 2;;
  esac
done

OS="$(uname -s)"; ARCH="$(uname -m)"
case "$ARCH" in x86_64) ARCH=amd64;; aarch64|arm64) ARCH=arm64;; esac

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yell()  { printf '\033[33m%s\033[0m\n' "$*"; }

MISSING=0
have() { command -v "$1" >/dev/null 2>&1; }

sudo_if_needed() { if [ -w /usr/local/bin ]; then "$@"; else sudo "$@"; fi; }

install_bin() { # name url
  local name="$1" url="$2" tmp; tmp="$(mktemp)"
  echo "    downloading $name ..."
  curl -fsSL "$url" -o "$tmp" && sudo_if_needed install -m 0755 "$tmp" "/usr/local/bin/$name" && rm -f "$tmp"
}

ensure() { # toolname install_fn version_cmd
  local tool="$1" fn="$2" vcmd="${3:-}"
  if have "$tool"; then
    green "  ✓ $tool $( [ -n "$vcmd" ] && eval "$vcmd" 2>/dev/null | head -1 )"
  else
    if $CHECK_ONLY; then red "  ✗ $tool MISSING"; MISSING=$((MISSING+1)); return; fi
    yell "  → installing $tool"
    if "$fn"; then green "  ✓ $tool installed"; else red "  ✗ $tool install FAILED"; MISSING=$((MISSING+1)); fi
  fi
}

# ---- per-tool installers -----------------------------------------------------
i_brew()       { /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; }
i_kubectl()    { if [ "$OS" = Darwin ]; then brew install kubectl; else install_bin kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"; fi; }
i_kind()       { if [ "$OS" = Darwin ]; then brew install kind; else install_bin kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"; fi; }
i_clusterctl() { if [ "$OS" = Darwin ]; then install_bin clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-darwin-${ARCH}"; else install_bin clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-${ARCH}"; fi; }
i_helm()       { if [ "$OS" = Darwin ]; then brew install helm; else curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; fi; }
i_colima()     { brew install colima; }
i_dockercli()  { if [ "$OS" = Darwin ]; then brew install docker; else echo "Install Docker Engine: https://docs.docker.com/engine/install/"; return 1; fi; }
i_k0sctl()     { if [ "$OS" = Darwin ]; then brew install k0sproject/tap/k0sctl; else install_bin k0sctl "https://github.com/k0sproject/k0sctl/releases/latest/download/k0sctl-linux-amd64"; fi; }
i_flux()       { curl -s https://fluxcd.io/install.sh | sudo_if_needed bash; }

check_clusterctl_pin() {
  if have clusterctl; then
    local v; v="$(clusterctl version -o short 2>/dev/null || clusterctl version 2>/dev/null | head -1)"
    case "$v" in *v1.9.*) green "  ✓ clusterctl is v1.9.x (serves cluster.x-k8s.io/v1beta1)";;
      *) yell "  ⚠ clusterctl '$v' is not v1.9.x — 5-Spot emits cluster.x-k8s.io/v1beta1; newer lines may not serve it. See docs/cli-setup.md.";; esac
  fi
}

ensure_docker_running() {
  if docker info >/dev/null 2>&1; then green "  ✓ docker daemon reachable"; return; fi
  if [ "$OS" = Darwin ] && have colima; then
    $CHECK_ONLY && { red "  ✗ docker daemon not running (start colima)"; MISSING=$((MISSING+1)); return; }
    yell "  → starting colima (--cpu 4 --memory ${COLIMA_MIN_MEM_GB})"
    colima start --cpu 4 --memory "$COLIMA_MIN_MEM_GB" --disk 60 && docker context use colima >/dev/null 2>&1
    docker info >/dev/null 2>&1 && green "  ✓ docker via colima" || { red "  ✗ docker still unreachable"; MISSING=$((MISSING+1)); }
  else
    red "  ✗ docker daemon not reachable — start Docker (Linux: systemctl start docker; macOS: colima start)"
    MISSING=$((MISSING+1))
  fi
}

# ---- tiers -------------------------------------------------------------------
[ -z "$TIER" ] && { red "required: --env-tier {codespaces|kind|hard}"; exit 2; }
echo "5-Spot bootstrap — tier: $TIER  ($OS/$ARCH)  $($CHECK_ONLY && echo CHECK-ONLY)"
echo

case "$TIER" in
  codespaces)
    # Inside a Codespace the devcontainer installs everything. When run outside
    # one (or after an incomplete rebuild), install whatever's missing instead of
    # failing — every tier should be able to fetch the tools it needs.
    if have docker; then
      green "  ✓ docker"
    else
      red "  ✗ docker missing — inside a Codespace, rebuild the container ('Rebuild Container'); locally, start Docker/Colima first"
      MISSING=$((MISSING+1))
    fi
    ensure kubectl i_kubectl "kubectl version --client | head -1"
    ensure kind i_kind "kind version"
    ensure clusterctl i_clusterctl "clusterctl version 2>/dev/null | head -1"
    ensure helm i_helm "helm version --short"
    check_clusterctl_pin
    ;;

  kind)
    if [ "$OS" = Darwin ]; then
      ensure brew i_brew "brew --version"
      ensure colima i_colima "colima version"
      ensure docker i_dockercli "docker --version"
    else
      have docker || { red "  ✗ docker — install Docker Engine first: https://docs.docker.com/engine/install/"; MISSING=$((MISSING+1)); }
    fi
    ensure kubectl i_kubectl "kubectl version --client | head -1"
    ensure kind i_kind "kind version"
    ensure clusterctl i_clusterctl "clusterctl version 2>/dev/null | head -1"
    ensure helm i_helm "helm version --short"
    check_clusterctl_pin
    ensure_docker_running
    ;;

  hard)
    # Full local k0smotron path + bonuses. Mac users: Colima-first (see setup-mac.sh).
    if [ "$OS" = Darwin ]; then
      ensure brew i_brew "brew --version"
      ensure colima i_colima "colima version"
      ensure docker i_dockercli "docker --version"
    else
      have docker || { red "  ✗ docker — install Docker Engine: https://docs.docker.com/engine/install/"; MISSING=$((MISSING+1)); }
    fi
    ensure kubectl i_kubectl "kubectl version --client | head -1"
    ensure kind i_kind "kind version"
    ensure clusterctl i_clusterctl "clusterctl version 2>/dev/null | head -1"
    ensure helm i_helm "helm version --short"
    ensure k0sctl i_k0sctl "k0sctl version | head -1"
    ensure flux i_flux "flux version --client 2>/dev/null | head -1"
    check_clusterctl_pin
    ensure_docker_running
    # CoCo bonus prerequisite probe (informational)
    if [ "$OS" = Linux ] && [ -e /dev/kvm ]; then
      green "  ✓ /dev/kvm present — Confidential Containers bonus is viable on this host"
    else
      yell "  ⚠ /dev/kvm not visible here — the ⭐⭐ CoCo bonus needs nested virt on the WORKER host."
      [ "$OS" = Darwin ] && yell "    (Apple Silicon cannot run x86 TEEs; use a Linux host for the CoCo bonus.)"
    fi
    ;;

  *) red "unknown tier '$TIER' — use codespaces|kind|hard"; exit 2;;
esac

echo
if [ "$MISSING" -gt 0 ]; then
  red "✗ $MISSING tool(s) missing or failed. Fix the above, or pick an easier tier (docs/quickstart-tiers.md)."
  exit 1
fi
green "✓ Tier '$TIER' is ready. Next: docs/quickstart-tiers.md"
