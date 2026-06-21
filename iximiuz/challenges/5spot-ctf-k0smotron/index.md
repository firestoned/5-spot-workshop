---
kind: challenge

title: '5-Spot CTF — Reclaim the Idle (REAL: k0s + k0smotron)'

description: |
  The production-representative scenario from the OSFF workshop: a hosted
  k0smotron control plane, with 5-Spot scheduling k0s workers onto a remote
  machine over SSH (RemoteMachine). Capture the lifecycle flags, then the
  Confidential Containers double-star bonus. Multi-node playground.

categories:
  - kubernetes
  - containers

tagz:
  - 5-spot
  - cluster-api
  - k0smotron
  - k0s
  - remotemachine

difficulty: hard

createdAt: 2026-06-19
updatedAt: 2026-06-19

cover: __static__/cover.png

# PLAYGROUND
# k0smotron needs a management host (kind mgmt cluster + k0smotron providers) AND a
# separate remote host to provision a k0s worker onto over SSH — so a multi-node
# base playground is required. The `mini-lan-ubuntu-docker` base playground gives
# four mutually reachable Ubuntu VMs with Docker (node-01..node-04, ~2 CPU/4 GiB
# each) — confirmed via the iximiuz playgrounds API. node-01 is the management
# host; node-02 is the RemoteMachine SSH target the k0s worker is provisioned onto.
#
# ⚠️ This scenario is heavier than the CAPD track and the per-node RAM (~4 GiB) is
#    tight for k0smotron. Treat the browser run as best-effort and SMOKE-TEST it on
#    a real 2-node env before the workshop (see docs/iximiuz-setup.md §4).
playground:
  name: mini-lan-ubuntu-docker

# All tasks pin to the management node (node-01) and run as the default root user
# (HOME=/root) — matching how the pre-bake/verifiers were written. (When `machine`
# is set, it must be set on ALL tasks.) Run your own shell commands as root
# (`sudo -i`) on node-01.
tasks:
  init_prebake:
    init: true
    machine: node-01
    timeout_seconds: 1800
    run: |
      set -e
      if [ ! -d /opt/wk/.git ]; then
        git clone --depth 1 https://github.com/firestoned/5-spot-workshop /opt/wk
      fi
      # The pre-bake provisions a k0s worker onto a remote SSH target. On this
      # playground that's node-02 (the pre-bake resolves the hostname → IP and
      # authorizes a generated key). node-01↔node-02 root SSH reachability is a
      # MiniLAN property; if the key push fails, see docs/iximiuz-setup.md §4.
      REMOTE_NODE_HOST=node-02 bash /opt/wk/workshop/5spot-ctf-k0smotron/setup-background.sh

  verify_window:
    machine: node-01
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-k0smotron/step1-deploy/verify.sh

  verify_compliant:
    machine: node-01
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-k0smotron/step2-taint/verify.sh

  verify_drain:
    machine: node-01
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-k0smotron/step3-drain/verify.sh

  verify_flux:
    machine: node-01
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-k0smotron/step4-flux-bonus/verify.sh

  verify_coco:
    machine: node-01
    timeout_seconds: 30
    run: |
      bash /opt/wk/workshop/5spot-ctf-k0smotron/step5-coco/verify.sh
---

This is the **production-representative** scenario the
[OSFF workshop](https://www.finos.org/hosted-events/2026-06-24-building-5-spot-workshop)
is built around — no Docker-provider shortcuts. Here the workload cluster's
**control plane is hosted** by k0smotron (runs as pods in the management cluster —
no node is burned for it), and 5-Spot schedules **k0s workers** by creating
`K0sWorkerConfig` + `RemoteMachine`, and k0smotron's controller **SSHes into a
remote host** to provision them.

> 5-Spot itself never SSHes anywhere — the `RemoteMachine` controller does.
> See [Prerequisites → Network](https://5spot.finos.org/installation/prerequisites/).

> ⚠️ **DRAFT — not yet validated end-to-end on iximiuz.** k0smotron API fields and
> version compatibility move, and the pre-bake's remote-host wiring must be adapted
> from a generic two-node layout to this playground (see the source TODOs). If a
> step misbehaves, check [docs.k0smotron.io](https://docs.k0smotron.io),
> [5-Spot CAPI Integration](https://5spot.finos.org/advanced/capi-integration/), and
> [Troubleshooting](https://5spot.finos.org/operations/troubleshooting/). Learn the
> lifecycle on the 🟢 Docker-provider challenge first if you prefer.

## What's being pre-baked

On the management node: a kind management cluster with CAPI core, the **k0smotron**
providers (`clusterctl init --bootstrap/--control-plane/--infrastructure
k0sproject-k0smotron`), cert-manager, the 5-Spot controller
(`ghcr.io/finos/5-spot:v0.2.2`), and a hosted `K0smotronControlPlane` for
`dev-cluster`. An SSH key is authorized on the remote node — the host a worker is
provisioned onto.

> **Run the workshop commands as `root`** on the management node (`sudo -i`); the
> kubeconfig is `/root/dev-cluster.kubeconfig`. Watch the pre-bake with
> `tail -f /tmp/5spot-setup.log`.

Ready when this responds:

```bash
kubectl --context kind-5spot-mgmt get cluster,k0smotroncontrolplane
```

---

## 🏁 Flag 1 — Open the window (provision a remote k0s worker)

The hosted control plane is up but has **no workers**. The `ScheduledMachine` ships
always-on; its `RemoteMachine.address` was set to the remote node during pre-bake.
Apply it to the **management** cluster:

```bash
kubectl --context kind-5spot-mgmt apply -f $HOME/5spot-workshop/scheduledmachine-k0smotron.yaml

kubectl --context kind-5spot-mgmt get k0sworkerconfig,remotemachine,machine \
  -l 5spot.finos.org/scheduled-machine=business-hours-worker

kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```

::simple-task
---
:tasks: tasks
:name: verify_window
---
#active
Waiting for the remote k0s worker to join the workload cluster…

#completed
Flag 1 captured — 5-Spot provisioned a worker over SSH. 🏁
::

::hint-box
---
:summary: Hint — worker not provisioned?
---

- `kubectl --context kind-5spot-mgmt get remotemachine,machine -A`
- `kubectl --context kind-5spot-mgmt describe remotemachine business-hours-worker`
- SSH reachability to the remote host + the `remote-ssh-key` Secret are the usual culprits.
- docs.k0smotron.io (capi-remote) · <https://5spot.finos.org/operations/troubleshooting/>
::

---

## 🏁 Flag 2 — Stay compliant on reclaimable capacity

5-Spot tainted the scheduled worker so only workloads that accept reclaim-risk land
there. Confirm the taint, then deploy the compliant (spot-tolerating) workload:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes \
  -o custom-columns=NODE:.metadata.name,TAINTS:.spec.taints

kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/spot-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -o wide -w
```

::simple-task
---
:tasks: tasks
:name: verify_compliant
---
#active
Waiting for `batch-cruncher` to land Running on the spot worker…

#completed
Flag 2 captured — a spot-tolerating workload rode the tainted node. 🏁
::

::hint-box
---
:summary: Hint — workload not scheduling?
---

- `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig describe pod -l app=batch-cruncher | tail -20`
::

---

## 🏁 Flag 3 — Survive the drain

Close the window. 5-Spot cordons → drains the node, then deletes the `Machine`,
`RemoteMachine`, and `K0sWorkerConfig` — and k0smotron resets the remote host.

```bash
kubectl --context kind-5spot-mgmt patch sm business-hours-worker \
  --type merge -p '{"spec":{"schedule":{"enabled":false}}}'

kubectl --context kind-5spot-mgmt get sm business-hours-worker -w
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```

> Emergency lever: `killSwitch: true` removes it immediately, bypassing the grace
> period — [Emergency Reclaim](https://5spot.finos.org/concepts/emergency-reclaim/).

::simple-task
---
:tasks: tasks
:name: verify_drain
---
#active
Waiting for the `ScheduledMachine` to reach `Inactive` and the worker to leave…

#completed
Flag 3 captured — graceful drain + remote host released. 🏁
::

::hint-box
---
:summary: Hint — drain not completing?
---

- `kubectl --context kind-5spot-mgmt logs -n 5spot-system deploy/5spot-controller | tail -30`
::

---

## ⭐ Bonus — GitOps the schedule with Flux

Make the `ScheduledMachine` declarative and reconciled from Git using
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
  path: ./workshop/5spot-ctf-k0smotron/assets/flux
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
::

---

## ⭐⭐ Stretch bonus — Confidential Containers on spot capacity

Run a **sensitive** workload on **reclaimable** spot capacity, protected inside a
hardware TEE / microVM via [Confidential Containers](https://confidentialcontainers.org/)
(CoCo). The scheduled worker host must have **nested virtualization / `/dev/kvm`**.

```bash
helm install coco oci://ghcr.io/confidential-containers/charts/confidential-containers \
  --version 0.18.0 --namespace coco-system --create-namespace \
  --kubeconfig $HOME/dev-cluster.kubeconfig
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig -n coco-system \
  wait --for=condition=Ready pods --all --timeout=5m

kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get runtimeclass | grep kata

kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/confidential-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -l app=confidential-cruncher -o wide -w
```

::simple-task
---
:tasks: tasks
:name: verify_coco
---
#active
Waiting for `confidential-cruncher` to run with a `kata*` runtime on the spot node…

#completed
Double-star flag captured — regulated data, on spot capacity, hardware-protected. 🏁🏁
::

::hint-box
---
:summary: Hint — CoCo pod not running?
---

- RuntimeClasses present? `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get runtimeclass`
- Worker needs `/dev/kvm` (nested virt). kind nodes: use `kata-clh`, not `kata-qemu-coco-dev`.
- `kubectl --kubeconfig $HOME/dev-cluster.kubeconfig describe pod -l app=confidential-cruncher | tail -30`
- Docs: <https://confidentialcontainers.org/docs/getting-started/>
::

---

## 🎉 You reclaimed the idle — on real remote infrastructure

You ran the full 5-Spot lifecycle against a **hosted k0smotron control plane**,
provisioning and reclaiming a **k0s worker over SSH**. In production you swap the
SSH host for your fleet (bare metal, edge, or any provider) — the `ScheduledMachine`
shape is identical. See [CAPI Integration](https://5spot.finos.org/advanced/capi-integration/)
· Contribute: <https://github.com/finos/5-spot> · `#5-spot` on
[FINOS Slack](https://finos.org/slack).
