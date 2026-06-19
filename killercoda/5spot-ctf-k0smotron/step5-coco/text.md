# ⭐⭐ Stretch bonus — Confidential Containers on spot capacity

The regulated-FS payoff: run a **sensitive** workload on **reclaimable** spot
capacity, protected inside a hardware TEE / microVM. A 5-Spot-scheduled node hosts a
[Confidential Containers](https://confidentialcontainers.org/) (CoCo) pod — memory
encrypted, attestable — so even ephemeral spot nodes can carry regulated data.

> **This is a true stretch goal with hardware prerequisites.** It only fits the 🔵
> k0smotron track, where the worker is a real VM/host — not the CAPD container track.

## Prerequisites (read first)

- The scheduled worker host must have **nested virtualization / `/dev/kvm`**.
  - **Physical/cloud Linux host (x86_64):** enable nested KVM — best path.
  - **Colima (macOS):** run the RemoteMachine target as a Linux/x86 Lima VM with
    nested virt; **Apple Silicon cannot do x86 TEE** — expect limited/no support.
  - **kind nodes:** use the `kata-clh` runtime class, *not* `kata-qemu-coco-dev`
    (QEMU is known not to work under kind).

Check KVM on the worker (over SSH to the host, or `kubectl debug node`):

```bash
ssh root@<worker-host> 'ls -l /dev/kvm && egrep -c "vmx|svm" /proc/cpuinfo'
```{{exec}}

## 1. Install the CoCo operator + runtime (Helm)

```bash
helm install coco oci://ghcr.io/confidential-containers/charts/confidential-containers \
  --version 0.18.0 --namespace coco-system --create-namespace \
  --kubeconfig $HOME/dev-cluster.kubeconfig
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig -n coco-system \
  wait --for=condition=Ready pods --all --timeout=5m
```{{exec}}

Confirm the runtime classes were created:

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get runtimeclass | grep kata
```{{exec}}

> Alt install (kustomize): `kubectl apply -k github.com/confidential-containers/operator/config/release?ref=<ver>` then the `samples/ccruntime/default` overlay.

## 2. Run the confidential workload on the spot node

```bash
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig apply -f $HOME/5spot-workshop/confidential-workload.yaml
kubectl --kubeconfig $HOME/dev-cluster.kubeconfig get pods -l app=confidential-cruncher -o wide -w
```{{exec}}

When `confidential-cruncher` is `Running` with a `kata*` runtime on the spot node,
hit **CHECK** for the double-star flag. 🏁🏁
