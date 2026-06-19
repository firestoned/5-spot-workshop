# 🎉 You reclaimed the idle

You ran the full 5-Spot lifecycle on real Cluster API infrastructure:

- 🏁 **Window opened** — one `ScheduledMachine` became a CAPI `Machine` +
  `KubeadmConfig` + `DockerMachine`, and a worker joined on schedule.
- 🏁 **Stayed compliant** — only a workload that *tolerated* the spot taint rode
  the reclaimable capacity.
- 🏁 **Survived the drain** — closing the window cordoned, drained, and removed the
  node gracefully (and you met the kill switch).
- ⭐ **GitOps bonus** — the schedule became declarative, reconciled from Git by Flux.

## Where this goes in production

The only things that change are the **providers** behind the bootstrap and infra
specs. Swap `DockerMachine` (CAPD) for `AWSMachine`, `Metal3Machine`,
`RemoteMachine`, etc. — the `ScheduledMachine` shape (`schedule`, `clusterName`,
`nodeTaints`, `gracefulShutdownTimeout`, `killSwitch`) is identical.

## Level up

- 🟡 **Medium:** run the bootstrap yourself in Codespaces or local `kind`.
- 🔴 **Hard:** build the controller from source (`make kind-load`), then defeat the
  CEL `ValidatingAdmissionPolicy` lock — apply a deliberately-broken
  `ScheduledMachine` and read the admission error to fix it.

## Contribute

5-Spot is a FINOS incubating project — issues, PRs, and the `#5-spot` Slack channel
are open: https://github.com/finos/5-spot
