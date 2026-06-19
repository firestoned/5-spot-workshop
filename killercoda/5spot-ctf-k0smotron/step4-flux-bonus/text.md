# ⭐ Bonus — GitOps the schedule with flux-operator

You've been driving 5-Spot with `kubectl apply` and `kubectl patch`. In a regulated
shop, that's an unaudited change. Let's make the `ScheduledMachine` **declarative
and reconciled from Git** — open and close the window by committing, not clicking.

We'll use [**flux-operator**](https://github.com/controlplaneio-fluxcd/flux-operator)
(installs and manages Flux via a `FluxInstance` CR).

**1. Install flux-operator** on the management cluster:

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
```{{exec}}

**2. Point Flux at the workshop repo** and reconcile the Flux overlay (which
contains *only* the `ScheduledMachine`). Replace the URL with your published
`5-spot-workshop` repo:

```bash
kubectl --context kind-5spot-mgmt apply -f - <<'EOF'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: workshop
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/YOUR-ORG/5-spot-workshop
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
  path: ./killercoda/5spot-ctf-k0smotron/assets/flux
  prune: true
  targetNamespace: default
EOF
```{{exec}}

**3. Confirm Flux now owns the schedule:**

```bash
kubectl --context kind-5spot-mgmt get kustomization -n flux-system scheduledmachine
kubectl --context kind-5spot-mgmt get sm business-hours-worker \
  -o jsonpath='{.metadata.labels}{"\n"}'
```{{exec}}

The `ScheduledMachine` now carries `kustomize.toolkit.fluxcd.io/*` labels — it's
managed by Git. Open/close the window by editing `scheduledmachine.yaml` in the
repo and pushing; Flux reconciles it. Hit **CHECK** for the bonus flag.

> ⚠️ This step needs the workshop repo to be public. For an offline room, swap the
> `GitRepository` for an `OCIRepository` or a local `git` served in-cluster.
