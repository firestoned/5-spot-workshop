# 🟡 Local kind tier — jump in (your machine, simplified track)

You chose to run it on your own laptop with the Docker provider — fast feedback,
works offline once images are cached, and nothing leaves your machine.

## Prerequisites

- **macOS**: 16 GB RAM recommended. One command installs everything
  (Homebrew, Colima, docker CLI, kubectl, kind, clusterctl v1.9.x, helm) and
  starts Colima sized correctly:

  ```bash
  ./scripts/setup-mac.sh          # --check to only report
  ```
- **Linux**: install [Docker Engine](https://docs.docker.com/engine/install/),
  then:

  ```bash
  ./scripts/5-spot-bootstrap.sh --env-tier kind
  ```
- **Windows**: this tier will fight you (WSL + nested Docker). Use
  [Codespaces](codespaces-setup.md) or [Killercoda](killercoda-user.md) instead.

## Jump in

```bash
git clone <workshop-repo-url> && cd 5-spot-workshop
./scripts/5-spot-bootstrap.sh --env-tier kind   # verifies/installs tooling
make kind                                       # full pre-bake: mgmt cluster + CAPI/CAPD + 5-Spot + workload cluster
```

Pre-bake takes ~5–10 minutes (longer on first run while images pull). Then play
the steps from `killercoda/5spot-ctf-capd/step*/text.md` — copy the commands
(skip the `{{exec}}` sugar) and capture flags with each step's verifier:

```bash
bash killercoda/5spot-ctf-capd/step1-deploy/verify.sh
```

*(Optional)* scoreboard join:
`printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "team" "https://…" > ~/.flagboard`

## Tier-specific gotchas

- **clusterctl must be v1.9.x** — 5-Spot emits `cluster.x-k8s.io/v1beta1`; newer
  lines may not serve it. `clusterctl version` to confirm; the bootstrap warns
  if you're off-line. ([why](cli-setup.md))
- **Colima sizing (macOS)**: kind + CAPD ≈ 4 containers. If pods evict or the
  workload cluster wedges: `colima stop && colima start --cpu 4 --memory 8 --disk 60`.
- Logs land at `/tmp/5spot-setup.log` when you're not root.
- Reset everything: `make kind-down && make kind`.

## Level up / help

The real k0smotron track and the bonuses live in [hard-setup.md](hard-setup.md).
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
[user-guide.md](user-guide.md) · [lab-guide.md](lab-guide.md)
