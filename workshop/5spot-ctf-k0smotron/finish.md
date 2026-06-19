# 🎉 You reclaimed the idle — on real remote infrastructure

You ran the full 5-Spot lifecycle against a **hosted k0smotron control plane**,
provisioning and reclaiming a **k0s worker over SSH**:

- 🏁 **Window opened** — `ScheduledMachine` → `K0sWorkerConfig` + `RemoteMachine`,
  and k0smotron SSHed in to join a real worker on schedule.
- 🏁 **Stayed compliant** — only a spot-tolerating workload rode the tainted node.
- 🏁 **Survived the drain** — closing the window drained the node and released the
  remote host gracefully.
- ⭐ **GitOps bonus** — the schedule reconciled from Git by Flux.
- ⭐⭐ **Confidential Containers bonus** — a sensitive workload ran inside a TEE/microVM
  on the reclaimable spot node: regulated data, on spot capacity, hardware-protected.

This is the topology from the OSFF workshop. In production you swap the SSH host for
your fleet (bare metal, edge, or any provider) — the `ScheduledMachine` shape is
identical. See [CAPI Integration](https://5spot.finos.org/advanced/capi-integration/).

## Go deeper
- [Concepts](https://5spot.finos.org/concepts/) · [Schedules](https://5spot.finos.org/concepts/schedules/) · [Emergency Reclaim](https://5spot.finos.org/concepts/emergency-reclaim/)
- [Security → Admission Validation](https://5spot.finos.org/security/admission-validation/)
- Contribute: https://github.com/finos/5-spot · `#5-spot` on [FINOS Slack](https://finos.org/slack)
