#!/usr/bin/env bash
# Codespaces post-create: install the pinned tools the devcontainer features don't cover.
set -euo pipefail
KIND_VERSION=v0.24.0
CLUSTERCTL_VERSION=v1.9.5   # v1.9.x serves cluster.x-k8s.io/v1beta1 (5-Spot requirement)
ARCH=$(dpkg --print-architecture)

curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
sudo install -m0755 /tmp/kind /usr/local/bin/kind
curl -fsSLo /tmp/clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-${ARCH}"
sudo install -m0755 /tmp/clusterctl /usr/local/bin/clusterctl
curl -s https://fluxcd.io/install.sh | sudo bash || true

echo "✓ devcontainer ready:"
for t in docker kubectl kind clusterctl helm flux; do printf '  %-12s %s\n' "$t" "$(command -v $t || echo MISSING)"; done
echo "Next: ./scripts/5-spot-bootstrap.sh --env-tier codespaces && make kind"
