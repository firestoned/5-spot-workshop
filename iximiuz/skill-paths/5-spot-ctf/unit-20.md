---
kind: unit

title: 'REAL track — k0s + k0smotron (RemoteMachine over SSH)'

name: k0smotron

createdAt: 2026-06-19
updatedAt: 2026-06-19

challenges:
  5spot-ctf-k0smotron: {}
---

::card
---
:challenge: challenges.5spot-ctf-k0smotron
---
::

**The real thing.** Now run the identical `ScheduledMachine` lifecycle against a
**hosted k0smotron control plane**, with 5-Spot provisioning **k0s workers onto a
remote host over SSH** (`RemoteMachine`) — the topology from the OSFF workshop. Same
flags, plus a Confidential Containers double-star stretch goal.

> ⚠️ This challenge is a **draft** and heavier on resources than the Docker-provider
> track — treat it as best-effort in the browser. See the challenge intro for the
> hardware/wiring caveats.
