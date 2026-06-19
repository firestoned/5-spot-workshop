# 🔵 REAL tier — k0s + k0smotron (RemoteMachine over SSH)

This is the **production-representative** scenario the
[OSFF workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop)
is built around — no Docker-provider shortcuts. Here:

- the workload cluster's **control plane is hosted** by k0smotron (runs as pods in
  the management cluster — no node is burned for it), and
- 5-Spot schedules **k0s workers** by creating `K0sWorkerConfig` + `RemoteMachine`,
  and k0smotron's controller **SSHes into a remote host** to provision them.

> 5-Spot itself never SSHes anywhere — the `RemoteMachine` controller does the SSH.
> See [Prerequisites → Network](https://5spot.finos.org/installation/prerequisites/).

## What's being pre-baked

On **node01**: a kind management cluster with CAPI core, the **k0smotron** providers
(`clusterctl init --bootstrap/--control-plane/--infrastructure k0sproject-k0smotron`),
cert-manager, the 5-Spot controller (`ghcr.io/finos/5-spot:v0.2.2`), and a hosted
`K0smotronControlPlane` for `dev-cluster`. An SSH key is authorized on **node02** —
that's the remote host a worker will be provisioned onto.

Ready when this responds:

```
kubectl --context kind-5spot-mgmt get cluster,k0smotroncontrolplane
```

Watch the pre-bake with `tail -f /opt/5spot-setup.log` (locally non-root: `/tmp/5spot-setup.log`).

> ⚠️ **This scenario is a DRAFT and not yet validated end-to-end.** k0smotron API
> fields and version compatibility move; if a step misbehaves, check
> [docs.k0smotron.io](https://docs.k0smotron.io),
> [5-Spot CAPI Integration](https://5spot.finos.org/advanced/capi-integration/), and
> [Troubleshooting](https://5spot.finos.org/operations/troubleshooting/). Compare with
> the 🟢 simplified (Docker) track if you want to learn the lifecycle first.


## Handy shortcuts

The pre-bake installs **kubectl aliases**, but a terminal you opened *before* it
finished won't have them yet — a running shell doesn't re-read its startup files.
Load them by re-launching your shell (click below), or just open a **new terminal tab**:

```
exec bash
```{{exec}}

Then you can type less:

- `k` → `kubectl` (with tab-completion)
- `kgp` → `get pods`, `kgpa` → `get pods -A`, `kgn` → `get nodes`, `kd` → `describe`, `kl` → `logs`
- `ksm` → `kubectl get sm -A` (the ScheduledMachines)
- `kmgmt` → `kubectl --context kind-5spot-mgmt` (the management cluster on node01)
- `kwl` → `kubectl --kubeconfig ~/dev-cluster.kubeconfig` (the hosted workload cluster)

Once loaded, `ksm` is the quick readiness check and `kgp -A` lists every pod.


## Join the live scoreboard (optional, 10 seconds)

If the facilitator shared a scoreboard URL/QR, register once and every flag you
capture posts itself when the verifier goes green:

```
printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "your-team-name" "https://PASTE-URL-HERE" > ~/.flagboard
```

No URL, no problem — everything works without it.

Continue when the hosted control plane is up. 🏁
