# 5-Spot Workshop — player's guide

## The story

Your fleet idles below 30% utilisation: worker capacity runs 24/7 but is only
needed in-window. [5-Spot](https://5spot.finos.org/) is a Kubernetes controller
that adds a worker when a schedule window opens and **gracefully drains and
removes it** when the window closes — spot capacity, on a schedule, with a full
audit trail. Today you deploy it, prove it, and try to break it.

## How the game works

- **Choose your adventure twice.** First a *scenario flavour* (🟢 simplified CAPD
  vs 🔵 real k0s + k0smotron), then an *environment tier* (Killercoda / Codespaces
  / local). See [quickstart-tiers.md](quickstart-tiers.md).
- **Capture flags.** Each challenge emits `FLAG{…}` when your cluster reaches the
  right state. On Killercoda press **CHECK**; elsewhere run the step's `verify.sh`.
- **Teams or solo** — both fine. Every player/team has their own sandbox.
- **Flags post themselves.** Run the join one-liner from the scenario intro once
  (team name + the scoreboard URL from the QR on screen); after that, every flag
  appears on the room monitor the moment your verifier goes green. Points: 100
  per core flag, 150 ⭐, 200 ⭐⭐.
- **Not feeling the game?** [docs/lab-guide.md](lab-guide.md) is the same
  material as a plain, linear walkthrough — no flags, no leaderboard.
- **You cannot break anything that matters.** Worst case, relaunch your sandbox.

## The flags

| # | Flag | What you prove | Key docs |
|---|------|----------------|----------|
| 1 | `…WINDOW_OPEN…` | A `ScheduledMachine` turns into real CAPI objects and a worker joins `Ready`. | [ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/) |
| 2 | `…RIDES_SPOT` | Only workloads that *tolerate* the spot taint land on reclaimable capacity. | [Concepts](https://5spot.finos.org/concepts/) |
| 3 | `…DRAIN_SURVIVED` | Closing the window cordons → drains → deletes within the grace period. | [Machine Lifecycle](https://5spot.finos.org/concepts/machine-lifecycle/) |
| ⭐ | `…RECONCILED_BY_FLUX` | The schedule is GitOps-managed, not `kubectl apply`'d. | step 4 |
| ⭐⭐ | `…ON_SPOT_TEE` | A sensitive workload runs in a TEE/microVM **on** the spot node. | [CoCo](https://confidentialcontainers.org/docs/getting-started/) |

## Things worth knowing before you start

- `sm` is the short name: `kubectl get sm -A`.
- 5-Spot evaluates schedules every ~60s — "nothing happened yet" often means
  "wait one tick".
- The lifecycle you'll watch: `Pending → Active → ShuttingDown → Inactive`
  (and `killSwitch: true` for [emergency reclaim](https://5spot.finos.org/concepts/emergency-reclaim/)).
- 5-Spot never SSHes anywhere itself — in the k0smotron track, the `RemoteMachine`
  controller does the SSH ([prerequisites](https://5spot.finos.org/installation/prerequisites/)).
- Controller logs are your friend:
  `kubectl -n 5spot-system logs deploy/5spot-controller --context kind-5spot-mgmt`

## Getting help during the workshop

1. The hints printed by a failing **CHECK** / `verify.sh`.
2. [Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) on the docs site.
3. Your table — seniors helping seniors is the point.
4. The facilitator (that's Erick — he wrote it, he can't hide).

## After the workshop

Star/contribute: [github.com/finos/5-spot](https://github.com/finos/5-spot) ·
join `#5-spot` on [FINOS Slack](https://finos.org/slack) · docs at
[5spot.finos.org](https://5spot.finos.org/).
