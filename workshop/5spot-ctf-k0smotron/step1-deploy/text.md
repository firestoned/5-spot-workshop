# 🏁 Flag 1 — Open the window (provision a remote k0s worker)

The hosted control plane is up but has **no workers**. Open a schedule window and
5-Spot will provision a k0s worker onto the remote host over SSH.

The `ScheduledMachine` ships always-on; its `RemoteMachine.address` was set to the
remote node's IP during pre-bake. Apply it to the **management** cluster:

```bash
kubectl --context kind-5spot-mgmt apply -f $HOME/5spot-workshop/scheduledmachine-k0smotron.yaml
```{{exec}}

Watch 5-Spot create the three objects (note `RemoteMachine`, not `DockerMachine`):

```bash
kubectl --context kind-5spot-mgmt get k0sworkerconfig,remotemachine,machine \
  -l 5spot.finos.org/scheduled-machine=business-hours-worker
```{{exec}}

k0smotron's `RemoteMachine` controller now SSHes to the host and runs the k0s join.
Watch the worker appear on the **workload** cluster:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```{{exec}}

> 📚 What each field does: [ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/) ·
> [Machine Lifecycle](https://5spot.finos.org/concepts/machine-lifecycle/)

When a worker node is `Ready`, hit **CHECK** for Flag 1.
