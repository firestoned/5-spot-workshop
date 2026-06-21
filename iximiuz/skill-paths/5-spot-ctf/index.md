---
kind: skill-path

title: '5-Spot CTF — Reclaim the Idle'

description: |
  A hands-on capture-the-flag through the 5-Spot machine scheduler: add worker
  capacity when a schedule window opens, keep workloads compliant on tainted spot
  capacity, and reclaim it with a graceful drain — first on a fast Docker-provider
  shortcut, then on the production-representative k0s + k0smotron (RemoteMachine
  over SSH) topology.

categories:
  - kubernetes
  - containers

tagz:
  - 5-spot
  - cluster-api
  - scheduling
  - finos

difficulties:
  - medium
  - hard

createdAt: 2026-06-19
updatedAt: 2026-06-19

cover: __static__/cover.png
---

Your dev/CI fleet idles below 30% because worker capacity runs 24/7 but is only
needed in-window. **5-Spot** (a [FINOS](https://github.com/finos/5-spot) incubating
project) adds a worker when a schedule window opens and gracefully drains + removes
it when it closes — *spot capacity, on a schedule*.

This skill path takes you through the full lifecycle twice:

1. 🟢 **Docker provider (CAPD)** — a fast learning shortcut where "machines" are
   sibling containers. Learn the moves with zero cloud or SSH.
2. 🔵 **k0s + k0smotron** — the production-representative track from the
   [OSFF workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop):
   a hosted control plane, with workers provisioned onto a remote host over SSH via
   `RemoteMachine`.

Both teach the identical `ScheduledMachine` lifecycle — 5-Spot is
[provider-agnostic](https://5spot.finos.org/advanced/capi-integration/). Each
challenge auto-checks your progress: capture the flags by driving real Cluster API
infrastructure, not by clicking "done".
