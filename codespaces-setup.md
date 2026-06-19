# 🟡 Codespaces tier — jump in (browser, full bootstrap)

You chose the cloud devbox: every tool pre-installed and pinned, but *you* run
the cluster bring-up — the full bootstrap experience without touching your
laptop. The right home for Windows users.

## Jump in

1. Open the workshop repo on GitHub → **Code ▸ Codespaces ▸ Create codespace on
   main**.
2. **Pick the machine type: 8-core / 16 GB** (click the `…` ▸ *New with
   options…* if you're not prompted). The 2-core default cannot hold
   kind + CAPI + a workload cluster.
3. Wait for the container build (a few minutes; with prebuilds enabled it's
   seconds). The devcontainer ships docker-in-docker, kubectl 1.31, helm, kind
   v0.24.0, **clusterctl v1.9.5** (the v1beta1-compatible line 5-Spot needs),
   and flux.
4. Verify, then bring the environment up yourself:

   ```bash
   ./scripts/5-spot-bootstrap.sh --env-tier codespaces
   make kind        # the same pre-bake Killercoda users get for free (~5–10 min)
   ```
5. *(Optional)* Join the scoreboard:
   `printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "team" "https://…" > ~/.flagboard`
6. Play the steps in order from `workshop/5spot-ctf-capd/step*/text.md`
   (ignore the `{{exec}}` markers — copy/paste the commands), and capture each
   flag by running its verifier:

   ```bash
   bash workshop/5spot-ctf-capd/step1-deploy/verify.sh
   ```

## Tier-specific gotchas

- **Free quota**: personal GitHub accounts get a monthly pool of core-hours
  (≈15 hrs on an 8-core machine) and the meter runs while the codespace is
  active — plenty for the workshop; **stop the codespace** afterwards
  (Code ▸ Codespaces ▸ Stop) so it doesn't idle-burn.
- Everything runs *inside* the codespace — `kubectl` in the built-in terminal,
  not your laptop's.
- Rebuilt or restarted? Tools persist; cluster state does not — rerun `make kind`.
- Want the **real** k0smotron track here? It works, but needs an SSH target —
  see [hard-setup.md](hard-setup.md) §RemoteMachine; localhost-as-target inside
  a codespace is unvalidated territory.

## Help

[cli-setup.md](cli-setup.md) (tool details) ·
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
[user-guide.md](user-guide.md) · plain walkthrough: [lab-guide.md](lab-guide.md)
