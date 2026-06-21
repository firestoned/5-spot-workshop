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
- **Windows** — use [Codespaces](codespaces-setup.md) or the [iximiuz browser lab](https://labs.iximiuz.com/skill-paths/5-spot-ctf-dc5a4cf4).

## You need an SSH target (the "remote machine")

The whole point of this tier: a worker is provisioned onto a real host over SSH.
Pick one:

- **macOS**: a second Colima/Lima VM. Start it and allow root login:
  ```bash
  colima start --profile node1 --cpu 2 --memory 2
  colima ssh --profile node1 -- sudo sh -c \
    'echo PermitRootLogin yes >> /etc/ssh/sshd_config && systemctl restart sshd'
  colima ls    # note node1's IP — this is your REMOTE_NODE_HOST below
  ```
- **Linux**: any reachable VM/box you can root-SSH into (a local libvirt VM, a
  spare machine, a €4 cloud instance for the afternoon).

> **Colima users — you authorise the key, not the script.** The pre-bake's
> key-authorisation step is best-effort: it assumes the management host already
> trusts the target (often true on a multi-node browser lab, **not** on Colima), so on a Mac it
> prints `could not auto-authorize` and moves on. You finish it by hand in the
> next section. Linux users SSH-ing into a box they already control can skip it.

## Jump in

```bash
REMOTE_NODE_HOST=<node1-ip-or-hostname> bash workshop/5spot-ctf-k0smotron/setup-background.sh
```

The pre-bake stands up: kind management cluster → cert-manager → CAPI core +
k0smotron providers → 5-Spot controller → SSH keypair generated (`~/remote_key`)
and stored as the `remote-ssh-key` Secret → hosted `K0smotronControlPlane` for
`dev-cluster`.

**macOS / Colima — authorise the key on node1 (after the pre-bake).** The
pre-bake (re)generates `~/remote_key` every run, so plant the public half *after*
it finishes, not before:

```bash
colima ssh --profile node1 -- sudo mkdir -p /root/.ssh
cat ~/remote_key.pub | colima ssh --profile node1 -- sudo tee -a /root/.ssh/authorized_keys >/dev/null
# sanity-check: the private key in the Secret can now log in
ssh -i ~/remote_key -o StrictHostKeyChecking=no root@<node1-ip> true && echo "SSH OK"
```

`colima ssh` already has its own access into the VM, so this plants the key
without needing prior root-SSH trust. With the key authorised, the worker can
join when you apply the ScheduledMachine. Then play
`workshop/5spot-ctf-k0smotron/step*/text.md` in order, verifying with each
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
