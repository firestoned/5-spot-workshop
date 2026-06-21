---
kind: unit

title: Reclaim the Idle — capture the flags

name: ctf

createdAt: 2026-06-21
updatedAt: 2026-06-21

challenges:
  5spot-ctf-capd-f3d76f57: {}
  5spot-ctf-k0smotron-153e9599: {}
---

Two tracks, the same five flags. **Start on the 🟢 Docker-provider (CAPD) track** to
learn the 5-Spot lifecycle fast — "machines" are sibling containers, no cloud or SSH.
Then take on the 🔵 **k0s + k0smotron** track for the production-representative thing:
a hosted control plane and a k0s worker provisioned onto a remote host over SSH.

Each challenge pre-bakes its cluster while you read, and every flag auto-checks as you
capture it.

::card
---
:challenge: challenges.5spot-ctf-capd-f3d76f57
---
::

::card
---
:challenge: challenges.5spot-ctf-k0smotron-153e9599
---
::
