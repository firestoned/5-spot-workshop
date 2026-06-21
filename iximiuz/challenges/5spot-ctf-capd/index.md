---
kind: challenge

title: '5-Spot CTF — Reclaim the Idle (Docker provider)'

description: |
  Deploy the 5-Spot machine scheduler on kind + Cluster API (Docker provider /
  CAPD) and capture the flags: open a schedule window so a worker joins, keep a
  workload compliant on tainted spot capacity, survive a graceful drain, and
  (bonus) reconcile the schedule from Git with Flux. The cluster is pre-baked to
  control-plane Ready while you read the intro.

categories:
  - kubernetes
  - containers

tagz:
  - 5-spot
  - cluster-api
  - capd
  - scheduling
  - finos

difficulty: medium

createdAt: 2026-06-19
updatedAt: 2026-06-19

cover: __static__/cover.png

# PLAYGROUND
# The `docker` base playground is a single Linux server (machine `docker-01`) with
# Docker pre-installed (4 CPU / 10 GiB RAM) — enough headroom for kind + CAPD's ~4
# sibling containers. Name/machine confirmed via the iximiuz playgrounds API. The
# single machine means tasks need no explicit `machine:` (they run on docker-01).
playground:
  name: docker

# TASKS
# - init_prebake runs ONCE on playground init (screen shows "loading" until done).
#   It clones this very repo and runs the EXISTING shared pre-bake script, so
#   there is a single source of truth for the bring-up logic.
# - The verify_* tasks are regular tasks: the engine runs each in a loop until it
#   exits 0, and the header shows how many are complete — that's the CTF scoring.
#   Each one just shells out to the EXISTING step verifier (which already exits
#   0/non-0 and self-posts to the flagboard).
#
# All tasks run as the default `root` user (HOME=/root) — matching how the shared
# pre-bake and verifiers were written. Run your own shell commands
# as root too (`sudo -i`), since the kubeconfig + clones live under /root.
tasks:
  init_prebake:
    init: true
    timeout_seconds: 1200
    run: |
      set -e
      if [ ! -d /opt/wk/.git ]; then
        git clone --depth 1 https://github.com/firestoned/5-spot-workshop /opt/wk
      fi
      bash /opt/wk/workshop/5spot-ctf-capd/setup-background.sh

  verify_window:
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-capd/step1-deploy/verify.sh

  verify_compliant:
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-capd/step2-taint/verify.sh

  verify_drain:
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-capd/step3-drain/verify.sh

  verify_flux:
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-capd/step4-flux-bonus/verify.sh
---

> ⚠️ **A learning shortcut, not a real-world setup.** This track uses Cluster API's
> **Docker provider (CAPD)** — "machines" are sibling containers — so you learn the
> 5-Spot lifecycle fast with zero cloud/SSH. The **production-representative**
> scenario is the 🔵 **k0s + k0smotron** challenge (`RemoteMachine` over SSH).
>
> 📚 5-Spot is provider-agnostic — see [CAPI Integration](https://5spot.finos.org/advanced/capi-integration/)
> and the [Quick Start](https://5spot.finos.org/installation/quickstart/).

It's quarter-end. Finance noticed your dev/CI fleet idles below 30% while you pay
for worker nodes 24/7. You've been handed **5-Spot** — a Kubernetes controller that
adds a worker when a schedule window opens and gracefully drains + removes it when
the window closes. *Spot capacity, on a schedule.*

## What's being pre-baked right now

While you read this, an init task is standing up your environment on the playground:

- a **kind** management cluster (`5spot-mgmt`) with the Docker socket mounted
- **Cluster API** core + kubeadm + the **Docker provider (CAPD)**
- the **5-Spot controller** (`ghcr.io/finos/5-spot:v0.2.2`)
- a **workload cluster** `dev-cluster` (1 control-plane node) + **Calico** CNI

The playground shows a loading screen until this finishes (a couple of minutes).

> **Run the workshop commands as `root`.** The pre-bake provisioned everything under
> `/root` (the kubeconfig is `/root/dev-cluster.kubeconfig`). Become root first:
>
> ```bash
> sudo -i
> ```
>
> Watch the pre-bake any time with `tail -f /tmp/5spot-setup.log`.

When this responds with an (empty) list of `ScheduledMachine`s, you're ready —
`sm` is the short name for 5-Spot's core CRD:

```bash
kubectl --context kind-5spot-mgmt get sm -A
```

---

## 🏁 Flag 1 — Open the window

Right now the workload cluster has only its control-plane node. Give it a worker —
but only when a schedule window is open. The manifest ships with an **always-on**
window (`mon-sun`, `0-23`) so the worker joins immediately. Apply it to the
**management** cluster:

```bash
kubectl --context kind-5spot-mgmt apply -f $HOME/5spot-workshop/scheduledmachine-business-hours.yaml
```

5-Spot turns that one `ScheduledMachine` into **three** CAPI objects:

```bash
kubectl --context kind-5spot-mgmt get kubeadmconfig,dockermachine,machine \
  -l 5spot.finos.org/scheduled-machine=business-hours-worker
```

Watch the worker Node join the **workload** cluster and go `Ready`:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```

::simple-task
---
:tasks: tasks
:name: verify_window
---
#active
Waiting for `business-hours-worker` to join the workload cluster and go Ready…

#completed
Flag 1 captured — the window opened and the worker joined. 🏁
::

::hint-box
---
:summary: Hint — worker not Ready?
---

- `kubectl --context kind-5spot-mgmt get sm business-hours-worker -o wide`
- `kubectl --context kind-5spot-mgmt describe machine business-hours-worker`
- `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes`
::

---

## 🏁 Flag 2 — Stay compliant on reclaimable capacity

The worker is **spot** capacity — it can vanish when the window closes. 5-Spot
stamped a taint on it so only workloads that explicitly accept that risk land there.
Confirm the taint, prove a non-tolerating pod stays `Pending`, then deploy the
compliant workload:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get node business-hours-worker \
  -o jsonpath='{.spec.taints}{"\n"}'

kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/spot-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -o wide -w
```

::simple-task
---
:tasks: tasks
:name: verify_compliant
---
#active
Waiting for `batch-cruncher` to land Running on `business-hours-worker`…

#completed
Flag 2 captured — a spot-tolerating workload rode the reclaimable node. 🏁
::

::hint-box
---
:summary: Hint — workload not scheduling?
---

- Did the worker keep its taint? `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig describe node business-hours-worker | grep -i taint`
- `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig describe pod -l app=batch-cruncher | tail -20`
::

---

## 🏁 Flag 3 — Survive the drain

The window is closing. 5-Spot doesn't just yank the node — it **cordons → evicts →
drains** within the grace period, *then* deletes the CAPI `Machine`,
`DockerMachine`, and `KubeadmConfig`. Close the window:

```bash
kubectl --context kind-5spot-mgmt patch sm business-hours-worker \
  --type merge -p '{"spec":{"schedule":{"enabled":false}}}'

kubectl --context kind-5spot-mgmt get sm business-hours-worker -w
```

Watch the node get cordoned and disappear — `batch-cruncher` is evicted gracefully,
not killed:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes,pods -o wide -w
```

> Want the "get it out NOW" lever? That's the kill switch:
> `--type merge -p '{"spec":{"killSwitch":true}}'` (bypasses the grace period; flip
> back to `false` afterwards).

::simple-task
---
:tasks: tasks
:name: verify_drain
---
#active
Waiting for the `ScheduledMachine` to reach `phase: Inactive` and the worker to leave…

#completed
Flag 3 captured — graceful cordon → drain → delete. 🏁
::

::hint-box
---
:summary: Hint — drain not completing?
---

- Did you set `spec.schedule.enabled=false`?
- Drain respects `gracefulShutdownTimeout`/`nodeDrainTimeout` — give it a moment.
- `kubectl --context kind-5spot-mgmt logs -n 5spot-system deploy/5spot-controller | tail -30`
::

---

## ⭐ Bonus — GitOps the schedule with Flux

Driving 5-Spot with `kubectl apply`/`patch` is an unaudited change. Make the
`ScheduledMachine` **declarative and reconciled from Git** using
[**flux-operator**](https://github.com/controlplaneio-fluxcd/flux-operator).

```bash
helm install flux-operator oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator \
  --namespace flux-system --create-namespace

kubectl --context kind-5spot-mgmt apply -f - <<'EOF'
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "2.x"
    registry: "ghcr.io/fluxcd"
  components: ["source-controller", "kustomize-controller"]
EOF
```

Point Flux at the workshop repo's Flux overlay (which contains *only* the
`ScheduledMachine`):

```bash
kubectl --context kind-5spot-mgmt apply -f - <<'EOF'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: workshop
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/firestoned/5-spot-workshop
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: scheduledmachine
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: workshop
  path: ./workshop/5spot-ctf-capd/assets/flux
  prune: true
  targetNamespace: default
EOF
```

::simple-task
---
:tasks: tasks
:name: verify_flux
---
#active
Waiting for the `ScheduledMachine` to be reconciled by a Flux `Kustomization`…

#completed
Bonus flag captured — the schedule is GitOps-managed. ⭐
::

::hint-box
---
:summary: Hint — Flux not reconciling?
---

- `kubectl --context kind-5spot-mgmt get fluxinstance -n flux-system`
- `kubectl --context kind-5spot-mgmt get gitrepository,kustomization -n flux-system`
- flux-operator + `FluxInstance` must be Ready before the `Kustomization` reconciles.
- This bonus needs the workshop repo to be public.
::

---

## 🎉 You reclaimed the idle

You ran the full 5-Spot lifecycle on real Cluster API infrastructure: opened a
window, stayed compliant on tainted spot capacity, survived a graceful drain, and
made it GitOps. In production you only swap the **providers** behind the bootstrap
and infra specs — the `ScheduledMachine` shape is identical. Next: try the 🔵
**k0s + k0smotron** challenge for the production-representative `RemoteMachine`
(SSH) topology.

5-Spot is a FINOS incubating project — issues, PRs, and `#5-spot` on
[FINOS Slack](https://finos.org/slack) are open: <https://github.com/finos/5-spot>
