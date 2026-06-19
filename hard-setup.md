# 🔴 Hard tier — jump in (production-faithful, local)

You chose the real thing: a hosted **k0smotron** control plane, with 5-Spot
scheduling **k0s workers over SSH** (`RemoteMachine`) — the topology from the
OSFF signup page. "Hard" means *faithful*, **not** compiled-from-source; building
the controller is an optional badge of honour.

## Prerequisites

- **macOS** — Colima-first, everything in one command (adds k0sctl + flux on top
  of the kind tier):

  ```bash
  ./scripts/setup-mac.sh          # --up to also boot the stack when done
  ```
- **Linux** — Docker Engine, then:

  ```bash
  ./scripts/5-spot-bootstrap.sh --env-tier hard
  ```
  Linux is also the best host for the ⭐⭐ Confidential Containers bonus
  (native `/dev/kvm`).
- **Windows** — use [Codespaces](codespaces-setup.md) or [Killercoda](killercoda-user.md).

## You need an SSH target (the "remote machine")

The whole point of this tier: a worker is provisioned onto a real host over SSH.
Pick one:

- **macOS**: a second Colima/Lima VM —
  `colima start --profile node1 --cpu 2 --memory 2`, note its IP from `colima ls`,
  ensure root SSH with your key is possible (the setup-mac.sh output shows the
  sshd snippet).
- **Linux**: any reachable VM/box you can root-SSH into (a local libvirt VM, a
  spare machine, a €4 cloud instance for the afternoon).

## Jump in

```bash
REMOTE_NODE_HOST=<ip-or-hostname> bash killercoda/5spot-ctf-k0smotron/setup-background.sh
```

The pre-bake stands up: kind management cluster → cert-manager → CAPI core +
k0smotron providers → 5-Spot controller → SSH key authorised on your target →
hosted `K0smotronControlPlane` for `dev-cluster`. Then play
`killercoda/5spot-ctf-k0smotron/step*/text.md` in order, verifying with each
step's `verify.sh`. Steps 4 (⭐ Flux) and 5 (⭐⭐ CoCo) are your bonuses.

Optional flexes:
- **Build from source**: `make kind-load` in [finos/5-spot](https://github.com/finos/5-spot)
  and point the deployment at your `local-dev` image.
- **Air-gapped mode**: the registry configuration story from the 5-Spot README —
  very on-brand for this audience.

## Tier-specific gotchas

- **This track is the least-trodden path** — k0smotron API fields move between
  releases. If `RemoteMachine` misbehaves, compare field names against your
  installed release ([docs.k0smotron.io](https://docs.k0smotron.io)) and check
  `kubectl describe remotemachine` events first.
- SSH is the usual culprit for a worker that never joins: key in the
  `remote-ssh-key` Secret, root login allowed on the target, IP reachable *from
  the management cluster's containers*.
- ⭐⭐ CoCo needs nested virt **on the worker host** (`ls /dev/kvm`). kind nodes →
  `kata-clh` runtime class; Apple Silicon cannot run x86 TEEs — use a Linux host.
- 5-Spot itself never SSHes — the RemoteMachine controller does
  ([prerequisites](https://5spot.finos.org/installation/prerequisites/)).

## Help

[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
[CAPI integration](https://5spot.finos.org/advanced/capi-integration/) ·
[user-guide.md](user-guide.md) · [lab-guide.md](lab-guide.md)
