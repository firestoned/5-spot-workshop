# 🏁 Flag 2 — Stay compliant on reclaimable capacity

The worker that just joined is **spot** capacity — it can vanish when the window
closes. 5-Spot stamped a taint on it so that *only workloads which explicitly
accept that risk* land there. Confirm the taint:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get node business-hours-worker \
  -o jsonpath='{.spec.taints}{"\n"}'
```{{exec}}

**First, prove the guard works.** Try a pod that does *not* tolerate the taint:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig run picky --image=registry.k8s.io/pause:3.10
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pod picky -o wide
```{{exec}}

It stays `Pending` — the control-plane is tainted too, so there's nowhere
compliant for it to go. Good. Clean it up:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig delete pod picky
```{{exec}}

**Now deploy the compliant workload** — it tolerates the spot taint:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/spot-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -o wide -w
```{{exec}}

When `batch-cruncher` is `Running` **on** `business-hours-worker`, hit **CHECK**.
