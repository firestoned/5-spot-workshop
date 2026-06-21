---
kind: training

title: |-
  5-Spot Capture The Flag — Reclaim the Idle

description: |-
  Operate the 5-Spot machine scheduler hands-on: open a schedule window so a worker joins, keep a workload running on tainted "spot" capacity, and survive a graceful drain — spot capacity, on a schedule.

categories:
- kubernetes
- containers

tagz:
- 5spot

createdAt: 2026-06-21
updatedAt: 2026-06-21

cover: __static__/cover.png
---

## Reclaim the Idle

Your fleet idles below 30% because worker capacity runs 24/7 but is only needed
in-window. **5-Spot** adds a worker when a schedule window opens and gracefully drains
and removes it when the window closes — *spot capacity, on a schedule.*

In this hands-on CTF you'll **operate** it: deploy the scheduler, prove a worker joins
when the window opens, keep a workload compliant on tainted "spot" capacity, survive a
graceful drain, and (bonus) reconcile the schedule from Git with Flux.

### How it works

- **Two tracks, the same flags** — start on the 🟢 simplified **Docker provider (CAPD)**
  track, then do the 🔵 production-representative **k0s + k0smotron** track.
- Each challenge **pre-bakes its cluster** while you read the intro — you start at the
  fun part.
- Every flag **auto-checks** as you capture it; the header tracks your progress.

Open the first challenge below to begin. 🏁
