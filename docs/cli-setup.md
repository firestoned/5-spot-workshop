# CLI Setup — get every tool the workshop needs

This installs the command-line tools used across all tiers. Do this **before** the
workshop (or it's pre-installed for you on the Easy browser-lab tier). Pins matter —
read the notes.

> 📚 5-Spot's own [Prerequisites](https://5spot.finos.org/installation/prerequisites/)
> page is the source of truth for cluster/CAPI requirements; this guide adds the
> exact CLI install commands.

| Tool | Needed for | Why |
|------|-----------|-----|
| `kubectl` | all tiers | Talk to the clusters. |
| `kind` | CAPD + k0smotron (local) | Run the management cluster in Docker. |
| `clusterctl` | all tiers | Install Cluster API + providers. **Pin matters.** |
| `helm` | Flux bonus | Install flux-operator. |
| `docker` / Colima | local tiers | Container runtime (Colima on macOS). |
| `k0sctl` | optional (Hard/k0s mgmt cluster) | Stand up a k0s management cluster instead of kind. |
| `flux` (CLI) | Flux bonus (optional) | Inspect Flux reconciliation. |

Pick **Linux** or **macOS** blocks below. Linux examples assume `amd64`; swap
`arm64` if needed. macOS examples use [Homebrew](https://brew.sh).

---

## kubectl

**Linux**
```bash
curl -LO "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
kubectl version --client
```

**macOS**
```bash
brew install kubectl    # or: brew install kubernetes-cli
```

> Pin to **v1.31.x** to match `kindest/node:v1.31.0` used in the scenarios.

## kind

**Linux**
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
sudo install -m 0755 kind /usr/local/bin/kind && rm kind
kind version
```

**macOS**
```bash
brew install kind
```

## clusterctl  ⚠️ version-sensitive

5-Spot emits CAPI `Machine` objects under **`cluster.x-k8s.io/v1beta1`**, so you
must install a Cluster API line that still **serves v1beta1**. The **v1.9.x** line
does. Don't grab "latest" blindly — newer lines may default to v1beta2.

**Linux**
```bash
CLUSTERCTL_VERSION=v1.9.5   # any v1.9.x; verify the tag exists on the releases page
curl -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VERSION}/clusterctl-linux-amd64" -o clusterctl
sudo install -m 0755 clusterctl /usr/local/bin/clusterctl && rm clusterctl
clusterctl version
```

**macOS**
```bash
brew install clusterctl    # then confirm: clusterctl version  (want v1.9.x)
# To pin exactly, download from the GitHub releases page instead of brew.
```

> Releases: https://github.com/kubernetes-sigs/cluster-api/releases
> See also 5-Spot's [CAPI Integration](https://5spot.finos.org/advanced/capi-integration/) notes.

## Docker / Colima (local container runtime)

**Linux** — install Docker Engine: https://docs.docker.com/engine/install/ — then:
```bash
sudo usermod -aG docker "$USER"   # log out/in so kind can use Docker rootless-free
docker run --rm hello-world
```

**macOS** — [Colima](https://github.com/abiosoft/colima) is the cost-free,
CLI-first Docker runtime (no Docker Desktop licence):
```bash
brew install colima docker
colima start --cpu 4 --memory 8 --disk 60     # bump memory for CAPD: ~4 containers
docker context use colima
docker run --rm hello-world
```
> For the **k0smotron** path you'll want SSH-able VMs as RemoteMachine targets —
> Colima can launch extra Lima VMs (`colima start --profile node1`). See the
> k0smotron scenario README.

## helm  (Flux bonus)

**Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
**macOS**
```bash
brew install helm
```

## k0sctl  (optional — k0s management cluster, Hard tier)

If you'd rather run the **management** cluster on k0s instead of kind:
**Linux/macOS**
```bash
# macOS
brew install k0sproject/tap/k0sctl
# Linux: grab the binary from the releases page
curl -L https://github.com/k0sproject/k0sctl/releases/latest/download/k0sctl-linux-amd64 -o k0sctl
sudo install -m 0755 k0sctl /usr/local/bin/k0sctl && rm k0sctl
k0sctl version
```
> k0sctl/k0s docs: https://docs.k0sproject.io — the management cluster just needs to
> be K8s 1.27+, so kind is the simpler default for the workshop.

## flux CLI  (optional, Flux bonus inspection)

**Linux/macOS**
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
flux version --client
```
> We install Flux itself via **flux-operator** (a Helm chart) inside the cluster —
> see the Flux bonus step. The `flux` CLI is only for poking at reconciliation.

---

## Quick sanity check

```bash
for c in kubectl kind clusterctl docker helm; do
  printf '%-12s ' "$c"; command -v "$c" >/dev/null && "$c" version --client 2>/dev/null | head -1 || echo "MISSING"
done
```

All present? Head to the scenario for your tier. Stuck? 5-Spot
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) and the
`#5-spot` channel on [FINOS Slack](https://finos.org/slack) are there for you.
