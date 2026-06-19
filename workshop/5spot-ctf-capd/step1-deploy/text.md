# 🏁 Flag 1 — Open the window

5-Spot is watching. Right now there are no `ScheduledMachine`s, so the workload
cluster has only its control-plane node. Let's give it a worker — but only when a
schedule window is open.

The manifest ships with an **always-on** window (`mon-sun`, `0-23`) so the worker
joins immediately. Apply it to the **management** cluster:

```bash
kubectl --context kind-5spot-mgmt apply -f $HOME/5spot-workshop/scheduledmachine-business-hours.yaml
```{{exec}}

5-Spot turns that one `ScheduledMachine` into **three** CAPI objects. Watch them
appear on the management cluster:

```bash
kubectl --context kind-5spot-mgmt get kubeadmconfig,dockermachine,machine \
  -l 5spot.finos.org/scheduled-machine=business-hours-worker
```{{exec}}

Now watch the worker Node join the **workload** cluster and go `Ready` (Ctrl-C when
it does):

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes -w
```{{exec}}

Check the schedule status:

```bash
kubectl --context kind-5spot-mgmt get sm business-hours-worker \
  -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.ready,IN_SCHEDULE:.status.inSchedule
```{{exec}}

When `business-hours-worker` is `Ready`, hit **CHECK** to capture Flag 1.
