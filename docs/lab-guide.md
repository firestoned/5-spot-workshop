# 5-Spot Lab Guide (plain walkthrough — no game)

Prefer a straight tutorial over the CTF? This is the same material as the
scenarios, as a linear lab. Skip the flags, the leaderboard, and the theming —
just deploy 5-Spot and exercise the full machine lifecycle.

Environment: any tier from [quickstart-tiers.md](quickstart-tiers.md). On
Killercoda the cluster is pre-baked; locally run
`bash killercoda/5spot-ctf-capd/setup-background.sh` (simplified) or the
k0smotron one (real). Paths below assume the pre-bake (`$HOME/5spot-workshop/`,
`$HOME/dev-cluster.kubeconfig`).

Throughout, the docs are your reference: [Quick Start](https://5spot.finos.org/installation/quickstart/) ·
[Concepts](https://5spot.finos.org/concepts/) · [API Reference](https://5spot.finos.org/reference/api/).

---

## 1. Orient yourself

Two clusters exist: a **management** cluster (kind, runs CAPI + the 5-Spot
controller) and a **workload** cluster (`dev-cluster`, currently has no workers).

```bash
kubectl --context kind-5spot-mgmt get pods -n 5spot-system        # the controller
kubectl --context kind-5spot-mgmt get crds | grep 5spot           # the CRD
kubectl --context kind-5spot-mgmt get sm -A                       # none yet — sm = ScheduledMachine
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes       # control plane only
```

## 2. Schedule a worker

A `ScheduledMachine` declares *when* a machine should exist. The workshop copy is
always-on so you see results immediately; a real one would say `mon-fri`, `9-17`.
Read it first — note `schedule`, `bootstrapSpec`, `infrastructureSpec`,
`nodeTaints`, `gracefulShutdownTimeout`
([field reference](https://5spot.finos.org/concepts/scheduled-machine/)):

```bash
cat $HOME/5spot-workshop/scheduledmachine-*.yaml
kubectl --context kind-5spot-mgmt apply -f $HOME/5spot-workshop/scheduledmachine-*.yaml
```

Watch one CRD become three CAPI objects, then a Node:

```bash
kubectl --context kind-5spot-mgmt get machine,sm -w               # phase: Pending → Active
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w    # worker joins, goes Ready
```

**Checkpoint:** `business-hours-worker` is `Ready` on the workload cluster, and
`kubectl get sm` shows `Active`. (Curious how? [Architecture flows](https://5spot.finos.org/architecture/flows/).)

## 3. Taints: who may use scheduled capacity

5-Spot stamped the worker with a taint — scheduled capacity is *reclaimable*, so
only workloads that opt in may land there:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get node business-hours-worker -o jsonpath='{.spec.taints}{"\n"}'
# Negative test: a pod with no toleration has nowhere to go
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig run picky --image=registry.k8s.io/pause:3.10
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pod picky          # Pending — good
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig delete pod picky
# Positive test: this Deployment tolerates the taint and prefers the spot pool
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/spot-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -o wide       # Running on the worker
```

**Checkpoint:** `batch-cruncher` is `Running` on `business-hours-worker`.

## 4. Close the window: graceful drain

This is the point of 5-Spot — removal is cordon → evict → drain → delete, inside
the grace period, not a yank
([machine lifecycle](https://5spot.finos.org/concepts/machine-lifecycle/)):

```bash
kubectl --context kind-5spot-mgmt patch sm business-hours-worker \
  --type merge -p '{"spec":{"schedule":{"enabled":false}}}'
kubectl --context kind-5spot-mgmt get sm business-hours-worker -w   # Active → ShuttingDown → Inactive
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes,pods -o wide -w
```

**Checkpoint:** phase `Inactive`, the worker gone, `batch-cruncher` evicted
gracefully. Re-enable the schedule and the worker comes back — try it.

Also meet the [emergency reclaim](https://5spot.finos.org/concepts/emergency-reclaim/):
`--type merge -p '{"spec":{"killSwitch":true}}'` skips the grace period
(phase `Terminated`); flip it back to `false` afterwards.

## 5. Optional: GitOps the schedule

Manage the `ScheduledMachine` from Git instead of kubectl — install
[flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator) and point
a `GitRepository` + `Kustomization` at the `assets/flux/` overlay. Full commands:
`killercoda/<scenario>/step4-flux-bonus/text.md` (ignore the `{{exec}}` markers —
they're Killercoda click-to-run sugar).

## 6. Optional: Confidential Containers

On a host with nested virtualisation, run the same compliant workload inside a
TEE/microVM on the scheduled node — `runtimeClassName` is the only change. Full
walkthrough and prerequisites: `killercoda/5spot-ctf-k0smotron/step5-coco/text.md`
and [confidentialcontainers.org](https://confidentialcontainers.org/docs/getting-started/).

## 7. Clean up

```bash
kind delete cluster --name 5spot-mgmt        # locally; Killercoda just expires
```

## Where to go next

[Operations & configuration](https://5spot.finos.org/operations/configuration/) ·
[Monitoring](https://5spot.finos.org/operations/monitoring/) ·
[HA](https://5spot.finos.org/advanced/ha/) ·
[Security & admission validation](https://5spot.finos.org/security/admission-validation/) ·
contribute at [github.com/finos/5-spot](https://github.com/finos/5-spot).
