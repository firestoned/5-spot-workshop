# 5-Spot Workshop — "Reclaim the Idle" CTF

A 2.5-hour, hands-on **capture-the-flag** that teaches the
[finos/5-spot](https://github.com/finos/5-spot) machine scheduler by making you
*operate* it: deploy it, watch a worker join when a schedule window opens, keep a
workload running on tainted "spot" capacity, and survive a graceful drain when the
window closes — *spot capacity, on a schedule.*

---

## Start here — pick your path

**Everyone captures the same flags.** Pick by your machine, not your skill level.

### 🌐 Browser lab — zero install (easiest)

Nothing to install. Open the hosted lab, press **Start**, and the cluster pre-bakes
itself while you read. Click **Check** (or run a verifier) to capture each flag.

- **iximiuz Labs** (skill path) → **https://labs.iximiuz.com/skill-paths/5-spot-ctf-dc5a4cf4**

### ☁️ Codespaces — browser, you run the bring-up

A cloud devbox with every tool pre-installed; you run the cluster. Best for Windows.

> Open **https://codespaces.new/firestoned/5-spot-workshop**, then in its terminal:
> ```bash
> ./scripts/5-spot-bootstrap.sh --env-tier codespaces && make kind
> ```

Full guide: **[docs/codespaces-setup.md](docs/codespaces-setup.md)**

### 💻 Local — your own machine

```bash
git clone https://github.com/firestoned/5-spot-workshop && cd 5-spot-workshop
./scripts/setup-mac.sh        # macOS: installs Colima + all tooling, sized right
# Linux: ./scripts/5-spot-bootstrap.sh --env-tier kind
make kind                     # pre-bakes the cluster (~5–10 min)
```

Full guide: **[docs/kind-setup.md](docs/kind-setup.md)** ·
real k0smotron track: **[docs/hard-setup.md](docs/hard-setup.md)**

---

> **New to the game?** **[docs/user-guide.md](docs/user-guide.md)** explains how flags
> work · **[docs/lab-guide.md](docs/lab-guide.md)** is the plain (non-CTF) walkthrough ·
> **[docs/quickstart-tiers.md](docs/quickstart-tiers.md)** compares every environment.
>
> **Facilitating?** Jump to [hosting the session](#im-facilitating--i-want-to-host-the-session).

---

## What this repo is

This is the **delivery kit for the workshop** — not the 5-Spot product itself
(that lives at [finos/5-spot](https://github.com/finos/5-spot)). Everything needed
to *run or attend* the session is here:

- **Two CTF scenarios** ([`workshop/`](workshop/)) — the same five flags on two
  Cluster API providers, from a learning shortcut to a production-faithful stack.
- **Per-tier setup/teardown tooling** ([`scripts/`](scripts/), [`Makefile`](Makefile),
  [`.devcontainer/`](.devcontainer/)) — one command readies a laptop, a Codespace,
  or a browser lab; another tears it all down.
- **A self-hosted leaderboard** ([`leaderboard/`](leaderboard/)) — flags post
  themselves to a projector-ready scoreboard; QR-code join; works on hostile WiFi.
- **Facilitator material** ([`docs/`](docs/), [`slides/`](slides/)) — runbooks,
  tier guides, and the deck.

It's the basis for the
[OSFF "Building 5-Spot" workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop).

---

## Choose your adventure

Two independent choices: **which scenario** (how real) and **which environment**
(how much you build).

### 1) Scenario flavour

| | Scenario | Providers | Real? |
|--|----------|-----------|-------|
| 🔵 | **k0s + k0smotron** — [`workshop/5spot-ctf-k0smotron/`](workshop/5spot-ctf-k0smotron/) | `K0sWorkerConfig` + `RemoteMachine` (SSH) | **Yes — production-representative.** This is what the [OSFF workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop) is built around. |
| 🟢 | **Docker provider (CAPD)** — [`workshop/5spot-ctf-capd/`](workshop/5spot-ctf-capd/) | `KubeadmConfig` + `DockerMachine` | **No — a learning shortcut.** "Machines" are sibling containers. Great for learning the lifecycle fast; *not* a real-world setup. |

Both teach the identical `ScheduledMachine` lifecycle — 5-Spot is
[provider-agnostic](https://5spot.finos.org/advanced/capi-integration/). Start on 🟢
to learn the moves; do 🔵 to see the real thing.

### 2) Environment tier (inclusive by design — pick for your laptop, not your skill)

| Tier | Where | You build | Best for |
|------|-------|-----------|----------|
| Easy | Browser lab (iximiuz — zero install) | Nothing — cluster pre-baked to control-plane Ready. | Focusing on concepts; locked-down laptops. |
| Medium | Codespaces / local `kind` | The bootstrap, fast path (pull the image, don't build). | Bootstrap muscle-memory without a Rust toolchain. |
| Hard | Full local / production-faithful (k0smotron) | Run the real stack end-to-end. Building the controller from source is **optional** — "Hard" means *real*, not *compiled*. Optionally defeat the admission-policy lock and add Confidential Containers. | Purists, contributors, air-gapped/regulated. |

**By operating system:**
- **macOS → Colima.** Free, CLI-first Docker runtime (no Docker Desktop licence), and it can spin extra Lima VMs as RemoteMachine / Confidential-Containers targets. See [docs/cli-setup.md](docs/cli-setup.md).
- **Windows → Codespaces or a browser lab.** Don't fight Docker Desktop / WSL nested-virt; run the browser/cloud tiers instead.
- **Linux → local Docker + kind** (or k0s). Best host for the Confidential Containers bonus, since nested KVM is straightforward.

> The k0smotron scenario is heavier (k0smotron controllers + hosted control plane +
> a remote worker). It runs best **local** or on a **2-node** browser lab; treat
> browser Easy as best-effort there.

---

## I'm facilitating — I want to host the session

`make help` is the menu. The typical flow:

```bash
make kind                       # rehearse the CAPD environment locally end-to-end
make test                       # static-check every tier (safe anywhere)
make test-live-kind             # boot CAPD + run all 3 flag verifiers for real
make flagboard                  # projector scoreboard + auto-posting flag API (:5050)
make leaderboard-tunnel PORT=5050   # free public https URL for the room
make salt-flags SALT=OSFF26     # invalidate the public GitHub flags on event morning
```

Full hosting runbooks:
- **[docs/iximiuz-setup.md](docs/iximiuz-setup.md)** — publish as a skill path of two challenges on iximiuz Labs (`make iximiuz-publish`).
- **[docs/codespaces-setup-facilitator.md](docs/codespaces-setup-facilitator.md)** — host the Medium tier on Codespaces (prebuilds, machine-type & cost policy).
- **[leaderboard/README.md](leaderboard/README.md)** — scoreboard options, QR join, public/flaky-WiFi handling.

The deck is in [slides/](slides/). When you're done, `make teardown TIER=<tier>` removes
everything (add `TEARDOWN_ARGS=--purge` to also delete clones/keys).

---

## The flags

| # | Challenge | Flag when… |
|---|-----------|------------|
| 1 | **Open the window** | the scheduled worker joins the workload cluster and goes `Ready`. |
| 2 | **Stay compliant** | a workload that *tolerates* the spot taint lands on the spot node. |
| 3 | **Survive the drain** | closing the window cordons → drains → deletes gracefully (`phase: Inactive`). |
| 4 | **Pick the lock** (Hard) | you fix a `ScheduledMachine` rejected by the CEL [ValidatingAdmissionPolicy](https://5spot.finos.org/security/admission-validation/). |
| ⭐ | **GitOps bonus** | the `ScheduledMachine` is reconciled by a Flux `Kustomization`, not `kubectl apply`. |
| ⭐⭐ | **Confidential Containers** (k0smotron track only) | a workload runs inside a TEE/microVM (`runtimeClassName: kata-qemu-coco-dev`) on the reclaimable spot node — sensitive data on spot capacity. Needs nested virt (`/dev/kvm`). |

In a browser lab the **Check** button runs the verifier; for Medium/Hard run the
step's `verify.sh`. Each player/team gets their own sandbox and submits their own
flags — **teams or solo both work**.

---

## Repository layout

| Path | What's there |
|------|--------------|
| [`workshop/5spot-ctf-capd/`](workshop/5spot-ctf-capd/) | 🟢 CAPD scenario — `intro.md`, `step*/` (text + `verify.sh`), `assets/` manifests, `setup-background.sh` pre-bake. |
| [`workshop/5spot-ctf-k0smotron/`](workshop/5spot-ctf-k0smotron/) | 🔵 k0smotron scenario — same shape, plus the ⭐⭐ Confidential Containers step. |
| [`iximiuz/`](iximiuz/) | iximiuz Labs content — a skill path of two challenges that reuse the same pre-bake/verifiers (`make iximiuz` to validate, `make iximiuz-publish` to publish). |
| [`scripts/`](scripts/) | `5-spot-bootstrap.sh` (install/verify tools per tier), `5-spot-teardown.sh` (full per-tier cleanup), `setup-mac.sh` (macOS one-shot), `test-tiers.sh` (static + live tier tests), `iximiuz-publish.sh`, `make-qr.sh`. |
| [`leaderboard/`](leaderboard/) | `flagboard.py` (zero-dep auto-posting scoreboard), `replay-captures.sh` (backfill captures recorded while offline), CTFd kit (`docker-compose.yml`, `seed-ctfd.py`). |
| [`docs/`](docs/) | Tier guides, the quickstart, user/lab guides, and the iximiuz hosting runbook. |
| [`.devcontainer/`](.devcontainer/) | Codespaces image + `post-create.sh` (installs the pinned tools). |
| [`slides/`](slides/) | The presenter deck and QR assets. |
| [`Makefile`](Makefile) | The facilitator menu (`make help`) — bring-up, teardown, tests, leaderboard, flag salting. |

---

## Leaderboard (QR-code flag submission)

**Flags post themselves**: every `verify.sh` carries a fire-and-forget hook that
submits the capture to `leaderboard/flagboard.py` — a zero-dependency live
wallboard you keep on the projector (`make flagboard`, free public URL via
`make leaderboard-tunnel PORT=5050`, QR via `make qr`). Captures are **also recorded
locally** (`~/.flagboard-captures.jsonl`), so a flaky network never loses a flag —
backfill with `make flagboard-replay` once the board is reachable. Players opt in
with one line; full details (including running on **public/conference WiFi**) in
[leaderboard/README.md](leaderboard/README.md).

Prefer the full CTF-platform experience? A self-hosted
[CTFd](https://github.com/CTFd/CTFd) kit lives in [leaderboard/](leaderboard/):
`make leaderboard-up` → seed it from the repo's own flags with
`make leaderboard-seed` → public URL with `make leaderboard-tunnel` →
`make qr URL=…` for the room. Salt the public flags on event morning with
`make salt-flags SALT=…`. A zero-ops Google Form fallback is in the same README.

---

## Facilitator notes

- **Prerequisites:** the bootstrap installs the rest, but you need Docker (or Colima
  on macOS), `git`, and `python3` (stdlib only — the leaderboard needs no pip
  installs). 8-core / 16 GB is the comfortable floor locally; free Codespaces tops
  out at **4-core / 16 GB** (the devcontainer requests it — enough for the CAPD track).
- **Image:** Easy/Medium pull `ghcr.io/finos/5-spot:v0.2.2` and `kind load` it.
  *(Confirm the exact published tag.)* Hard can optionally build from source.
- **clusterctl pin:** a **v1.9.x** line (still serves `cluster.x-k8s.io/v1beta1`,
  which 5-Spot emits). k0smotron installs via
  `clusterctl init --bootstrap/--control-plane/--infrastructure k0sproject-k0smotron`.
- **⚠️ Smoke-test the pre-bake** on a free browser-lab env before the event
  (especially k0smotron). Fallbacks: pre-baked VM image (Hetzner/Civo London) or
  Codespaces.
- **The k0smotron scenario is currently a DRAFT** — validate API fields/versions
  against your installed k0smotron release; it is not yet tested end-to-end.

## Roadmap

- [x] Codespaces devcontainer · [x] tier bootstrap + mac setup scripts · [x] facilitator Makefile + automated tier tests · [x] slides
- [x] full per-tier teardown (`make teardown` / `make clean`)
- [x] team leaderboard (CTFd kit + QR + flag salting) · [x] offline capture recording + replay
- [x] iximiuz Labs skill path (two challenges, shared pre-bake/verifiers)
- [ ] `hard-local/` admission-policy lock challenge
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
