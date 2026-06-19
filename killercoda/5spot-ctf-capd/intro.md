# 🟢 Simplified track (Docker provider) — welcome to the war room

> ⚠️ **This is a learning shortcut, not a real-world setup.** It uses Cluster API's
> **Docker provider (CAPD)** — "machines" are sibling containers — so you can learn
> the 5-Spot lifecycle fast with zero cloud/SSH. The **production-representative**
> scenario is the 🔵 **k0s + k0smotron** track (`RemoteMachine` over SSH), which is
> what the OSFF workshop is built around. Do this one to learn the moves; do the
> k0smotron one to see the real thing.
>
> 📚 5-Spot is provider-agnostic — see [CAPI Integration](https://5spot.finos.org/advanced/capi-integration/)
> and the [Quick Start](https://5spot.finos.org/installation/quickstart/).

It's quarter-end. Finance has noticed your dev/CI fleet idles below 30% while you
pay for worker nodes 24/7. You've been handed **5-Spot** — a Kubernetes controller
that adds a worker when a schedule window opens and gracefully drains + removes it
when the window closes. *Spot capacity, on a schedule.*

Your laptop is fine. We've already done the boring part for you.

## What's being pre-baked right now

While you read this, a background script is standing up your environment:

- a **kind** management cluster (`5spot-mgmt`) with the Docker socket mounted
- **Cluster API** core + kubeadm + the **Docker provider (CAPD)**
- the **5-Spot controller** (`ghcr.io/finos/5-spot:v0.2.2`)
- a **workload cluster** `dev-cluster` (1 control-plane node) + **Calico** CNI

This takes a couple of minutes. When the terminal prompt is responsive and the
command below works, you're ready:

```
kubectl --context kind-5spot-mgmt get sm -A
```

`sm` is the short name for `ScheduledMachine` — 5-Spot's core CRD. Right now there
are none. **Your job is to create one and capture three flags.**

> Stuck waiting? Run `tail -f /opt/5spot-setup.log` (locally non-root: `/tmp/5spot-setup.log`) to watch the pre-bake.


## Join the live scoreboard (optional, 10 seconds)

If the facilitator shared a scoreboard URL/QR, register once and every flag you
capture posts itself when the verifier goes green:

```
printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "your-team-name" "https://PASTE-URL-HERE" > ~/.flagboard
```

No URL, no problem — everything works without it.

Press **START** / continue when the cluster is up. 🏁
