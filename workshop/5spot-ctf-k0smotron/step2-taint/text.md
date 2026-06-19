# 🏁 Flag 2 — Stay compliant on reclaimable capacity

5-Spot tainted the scheduled worker so only workloads that accept reclaim-risk land
there. Confirm the taint:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get nodes \
  -o custom-columns=NODE:.metadata.name,TAINTS:.spec.taints
```{{exec}}

Deploy the compliant workload (it tolerates the spot taint):

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/spot-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -o wide -w
```{{exec}}

> 📚 Taints/labels on scheduled nodes: [ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/)

When `batch-cruncher` is `Running` on the spot worker, hit **CHECK**.
