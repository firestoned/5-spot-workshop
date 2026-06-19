# 🏁 Flag 3 — Survive the drain

Close the window. 5-Spot cordons → drains the node, then deletes the `Machine`,
`RemoteMachine`, and `K0sWorkerConfig` — and k0smotron resets the remote host.

```bash
kubectl --context kind-5spot-mgmt patch sm business-hours-worker \
  --type merge -p '{"spec":{"schedule":{"enabled":false}}}'
```{{exec}}

Watch the phase walk `Active → ShuttingDown → Inactive` and the node leave:

```bash
kubectl --context kind-5spot-mgmt get sm business-hours-worker -w
```{{exec}}
```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```{{exec}}

> Emergency lever: `killSwitch: true` removes it immediately, bypassing the grace
> period — [Emergency Reclaim](https://5spot.finos.org/concepts/emergency-reclaim/).

When the SM is `Inactive` and the worker is gone, hit **CHECK** for Flag 3.
