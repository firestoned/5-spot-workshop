# 🏁 Flag 3 — Survive the drain

The window is closing (end of business hours, or the spot capacity is being
reclaimed). This is the whole point of 5-Spot: it doesn't just yank the node — it
**cordons → evicts → drains** within the grace period, *then* deletes the CAPI
`Machine`, `DockerMachine`, and `KubeadmConfig`.

Close the window by disabling the schedule:

```bash
kubectl --context kind-5spot-mgmt patch sm business-hours-worker \
  --type merge -p '{"spec":{"schedule":{"enabled":false}}}'
```{{exec}}

Watch the phase walk through `Active → ShuttingDown → Inactive`:

```bash
kubectl --context kind-5spot-mgmt get sm business-hours-worker -w
```{{exec}}

And watch the Node get cordoned and disappear from the workload cluster — notice
`batch-cruncher` gets evicted gracefully, not killed:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes,pods -o wide -w
```{{exec}}

> Want the "get it out NOW" lever instead of a graceful close? That's the kill
> switch: `--type merge -p '{"spec":{"killSwitch":true}}'`. It bypasses the
> grace period. (Flip it back to `false` afterwards.)

When the `ScheduledMachine` reaches `phase: Inactive` and the worker is gone,
hit **CHECK** for Flag 3.
