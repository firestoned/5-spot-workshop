# 5-Spot Workshop — "Reclaim the Idle" CTF

A 2.5-hour, hands-on, **choose-your-own-adventure** workshop for the
[finos/5-spot](https://github.com/finos/5-spot) machine scheduler.
Built on the project's docs ([5spot.finos.org](https://5spot.finos.org/)) and its
[`examples/workshop`](https://github.com/finos/5-spot/tree/main/examples/workshop).

> **The scenario.** Your fleet idles below 30% because worker capacity runs 24/7 but
> is only needed in-window. `5-Spot` adds a worker when a schedule window opens and
> gracefully drains + removes it when it closes — *spot capacity, on a schedule*.
> Mission: deploy it, prove a worker joins, keep a workload compliant on tainted
> "spot" capacity, survive a graceful drain, and (bonus) do it GitOps-style with Flux.

---

## Choose your adventure

Two independent choices: **which scenario** (how real) and **which environment**
(how much you build). Everyone captures the same flags.

### 1) Scenario flavour

| | Scenario | Providers | Real? |
|--|----------|-----------|-------|
| 🔵 | **k0s + k0smotron** — [`killercoda/5spot-ctf-k0smotron/`](killercoda/5spot-ctf-k0smotron/) | `K0sWorkerConfig` + `RemoteMachine` (SSH) | **Yes — production-representative.** This is what the [OSFF workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop) is built around. |
| 🟢 | **Docker provider (CAPD)** — [`killercoda/5spot-ctf-capd/`](killercoda/5spot-ctf-capd/) | `KubeadmConfig` + `DockerMachine` | **No — a learning shortcut.** "Machines" are sibling containers. Great for learning the lifecycle fast; *not* a real-world setup. |

Both teach the identical `ScheduledMachine` lifecycle — 5-Spot is
[provider-agnostic](https://5spot.finos.org/advanced/capi-integration/). Start on 🟢
to learn the moves; do 🔵 to see the real thing.

### 2) Environment tier (inclusive by design — pick for your laptop, not your skill)

| Tier | Where | You build | Best for |
|------|-------|-----------|----------|
| Easy | Killercoda (browser, zero install) | Nothing — cluster pre-baked to control-plane Ready. | Focusing on concepts; locked-down laptops. |
| Medium | Codespaces / local `kind` | The bootstrap, fast path (pull the image, don't build). | Bootstrap muscle-memory without a Rust toolchain. |
| Hard | Full local / production-faithful (k0smotron) | Run the real stack end-to-end. Building the controller from source (`make kind-load`) is **optional**, not required — "Hard" means *real*, not *compiled*. Optionally defeat the admission-policy lock and add Confidential Containers. | Purists, contributors, air-gapped/regulated. |

**By operating system:**
- **macOS → Colima.** Free, CLI-first Docker runtime (no Docker Desktop licence), and it can spin extra Lima VMs as RemoteMachine / Confidential-Containers targets. See [docs/cli-setup.md](docs/cli-setup.md).
- **Windows → Codespaces or Killercoda.** Don't fight Docker Desktop / WSL nested-virt; run the browser/cloud tiers instead.
- **Linux → local Docker + kind** (or k0s). Best host for the Confidential Containers bonus, since nested KVM is straightforward.

> The k0smotron scenario is heavier (k0smotron controllers + hosted control plane +
> a remote worker). It runs best **local** or on a **2-node** Killercoda env; treat
> browser Easy as best-effort there. See the Killercoda guide.

---

## For facilitators

`make help` is the menu. Highlights: `make killercoda` / `make codespaces` / `make
kind` scaffold-and-verify each platform; `make test` static-checks every tier
anywhere; `make test-live-kind` boots the full CAPD environment and runs all three
flag verifiers end-to-end (and `make test-live-k0smotron` with
`REMOTE_NODE_HOST=<ssh-host>` for the real track). The deck lives in
[slides/](slides/).

## For users

One command readies any tier:

```bash
./scripts/5-spot-bootstrap.sh --env-tier <killercoda|codespaces|kind|hard>
```

macOS Hard tier (checks/installs Homebrew, Colima, and all tooling):

```bash
./scripts/setup-mac.sh        # --check to report only, --up to also boot the stack
```

Start here: **[docs/quickstart-tiers.md](docs/quickstart-tiers.md)** (pick your
environment) and **[docs/user-guide.md](docs/user-guide.md)** (how the game works).
Not into the CTF? **[docs/lab-guide.md](docs/lab-guide.md)** is the plain walkthrough.

Once you've chosen your adventure, each tier has its own jump-in guide:
[🟢 Killercoda](docs/killercoda-user.md) ·
[🟡 Codespaces](docs/codespaces-setup.md) ·
[🟡 local kind](docs/kind-setup.md) ·
[🔴 Hard / k0smotron](docs/hard-setup.md)

## Setup guides

- **[docs/cli-setup.md](docs/cli-setup.md)** — install `kubectl`, `kind`,
  `clusterctl` (with the version pin that matters), `helm`, Docker/Colima, `k0sctl`,
  and the `flux` CLI, on macOS and Linux.
- **[docs/killercoda-setup.md](docs/killercoda-setup.md)** — host both scenarios on
  Killercoda (free): repo wiring, the `index.json` contract, single- vs 2-node
  backends (the 2nd node is the RemoteMachine SSH target), resource smoke-test, and
  testing locally before you push.

## The flags

| # | Challenge | Flag when… |
|---|-----------|------------|
| 1 | **Open the window** | the scheduled worker joins the workload cluster and goes `Ready`. |
| 2 | **Stay compliant** | a workload that *tolerates* the spot taint lands on the spot node. |
| 3 | **Survive the drain** | closing the window cordons → drains → deletes gracefully (`phase: Inactive`). |
| 4 | **Pick the lock** (Hard) | you fix a `ScheduledMachine` rejected by the CEL [ValidatingAdmissionPolicy](https://5spot.finos.org/security/admission-validation/). |
| ⭐ | **GitOps bonus** | the `ScheduledMachine` is reconciled by a Flux `Kustomization`, not `kubectl apply`. |
| ⭐⭐ | **Confidential Containers** (k0smotron track only) | a workload runs inside a TEE/microVM (`runtimeClassName: kata-qemu-coco-dev`) on the reclaimable spot node — sensitive data on spot capacity. Needs nested virt (`/dev/kvm`). |

In Killercoda the **CHECK** button runs the verifier; for Medium/Hard run `verify.sh`.

## Teams or solo

Both work — each player/team gets their own sandbox and submits their own flags.

## Leaderboard (QR-code flag submission)

**Flags post themselves**: every `verify.sh` carries a fire-and-forget hook that
submits the capture to `leaderboard/flagboard.py` — a zero-dependency live
wallboard you keep on the projector (`make flagboard`, free public URL via
`make leaderboard-tunnel PORT=5050`, QR via `make qr`). Players opt in with one
line; details in [leaderboard/README.md](leaderboard/README.md). Prefer the full
CTF platform experience? A self-hosted [CTFd](https://github.com/CTFd/CTFd) kit lives in
[leaderboard/](leaderboard/): `make leaderboard-up` → seed it from the repo's own
flags with `make leaderboard-seed` → get a free public URL with
`make leaderboard-tunnel` → `make qr URL=…` for the room. Salt the public flags on
event morning with `make salt-flags SALT=…`. Zero-ops fallback (Google Form) is
documented in the same README.

## Facilitator notes

- **Image:** Easy/Medium pull `ghcr.io/finos/5-spot:v0.2.2` and `kind load` it.
  *(Confirm the exact published tag.)* Hard builds via `make kind-load`.
- **clusterctl pin:** a **v1.9.x** line (still serves `cluster.x-k8s.io/v1beta1`,
  which 5-Spot emits). k0smotron installs via
  `clusterctl init --bootstrap/--control-plane/--infrastructure k0sproject-k0smotron`.
- **⚠️ Smoke-test the pre-bake** on a free Killercoda env before the event
  (especially k0smotron). Fallbacks: pre-baked VM image (Hetzner/Civo London) or
  Codespaces.
- **The k0smotron scenario is currently a DRAFT** — validate API fields/versions
  against your installed k0smotron release; it is not yet tested end-to-end.

## Roadmap

- [x] Codespaces devcontainer · [x] tier bootstrap + mac setup scripts · [x] facilitator Makefile + automated tier tests · [x] slides
- [ ] `hard-local/` admission-policy lock challenge
- [x] team leaderboard (CTFd kit + QR + flag salting)
- [ ] standalone `flux-bonus/` overlay
- [ ] validate the k0smotron scenario end-to-end on a 2-node env

## Docs & community

[Quick Start](https://5spot.finos.org/installation/quickstart/) ·
[Concepts](https://5spot.finos.org/concepts/) ·
[ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/) ·
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
[API Reference](https://5spot.finos.org/reference/api/) ·
`#5-spot` on [FINOS Slack](https://finos.org/slack)

## Licence

Intended to ship under Apache-2.0 to match finos/5-spot.
