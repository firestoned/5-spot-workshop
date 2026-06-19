# Quick guide — pick your environment and go

Three ways to play. Same flags, same lessons. Pick for your **laptop and OS**, not
your skill level.

| Your situation | Use |
|---|---|
| Locked-down laptop, no Docker, or just want zero setup | 🟢 **Killercoda** |
| Windows | 🟡 **Codespaces** (or Killercoda) |
| macOS | 🟡 kind via **Colima**, or 🔴 Hard via `scripts/setup-mac.sh` |
| Linux | any tier — and the best host for the ⭐⭐ CoCo bonus |

---

## 🟢 Killercoda (browser — zero install)

*Full guide: [killercoda-user.md](killercoda-user.md)*

1. Open the course — **https://killercoda.com/5-spot/course/workshop** — and pick:
   - *Simplified (CAPD)* — learning shortcut, **not** real-world
   - *Real (k0s + k0smotron)* — production-representative track
2. Press **START**. The environment pre-bakes itself (~2–5 min). Read the intro
   while you wait; `tail -f /opt/5spot-setup.log` shows progress.
3. Each step ends with a **CHECK** button — that's the flag verifier. Green = flag
   captured, move on.

Nothing to install. If the session dies (free-tier time limits), just relaunch.

## 🟡 Codespaces (browser — full bootstrap experience)

*Full guide: [codespaces-setup.md](codespaces-setup.md)*

1. Open the workshop repo on GitHub → **Code ▸ Codespaces ▸ Create codespace**.
   Pick an **8-core / 16 GB** machine type (the default 2-core is too small).
2. Wait for the container build (the devcontainer installs docker, kubectl, kind,
   clusterctl *pinned to v1.9.x*, helm, flux).
3. Verify, then bring the environment up yourself:

   ```bash
   ./scripts/5-spot-bootstrap.sh --env-tier codespaces
   make kind        # runs the same pre-bake Killercoda users get for free
   ```
4. Play the steps from `workshop/5spot-ctf-capd/step*/text.md` in order, running
   each `verify.sh` yourself to capture flags:

   ```bash
   bash workshop/5spot-ctf-capd/step1-deploy/verify.sh
   ```

## 🟡 kind (local) / 🔴 Hard (local, production-faithful)

*Full guides: [kind-setup.md](kind-setup.md) · [hard-setup.md](hard-setup.md)*

**macOS** — one command checks/installs everything (Homebrew, **Colima**, docker,
kubectl, kind, clusterctl, helm, k0sctl, flux) and starts Colima sized right:

```bash
./scripts/setup-mac.sh            # add --check to only report, --up to also boot the stack
```

**Linux** — install Docker Engine first, then:

```bash
./scripts/5-spot-bootstrap.sh --env-tier kind    # Medium
./scripts/5-spot-bootstrap.sh --env-tier hard    # Hard (adds k0sctl, flux, CoCo probe)
```

**Windows** — don't fight WSL/nested virt: use **Codespaces** or **Killercoda**.

Then bring it up and play:

```bash
make kind                                        # CAPD environment (simplified)
# or the real thing:
bash workshop/5spot-ctf-k0smotron/setup-background.sh    # k0smotron (needs an SSH target)
```

Hard-tier extras (all optional — "Hard" means *real*, not *compiled*):
- Build the controller from source: `make kind-load` in the
  [finos/5-spot](https://github.com/finos/5-spot) repo.
- A second Colima VM as the RemoteMachine SSH target: `colima start --profile node1`.
- The ⭐⭐ Confidential Containers bonus — Linux host with `/dev/kvm` recommended.

---

**Stuck?** [docs/user-guide.md](user-guide.md) ·
[5spot.finos.org Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
`#5-spot` on [FINOS Slack](https://finos.org/slack)
