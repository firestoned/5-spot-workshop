# 🟡 Codespaces — jump in (browser, nothing to install)

A cloud devbox with every tool pre-installed. You run the cluster; your laptop
stays clean. Best path for Windows.

## After your Codespace opens — 3 steps

```bash
# 1) Bring the cluster up (~5–10 min the first time)
./scripts/5-spot-bootstrap.sh --env-tier codespaces && make kind

# 2) Capture a flag (green ✓ = captured)
bash workshop/5spot-ctf-capd/step1-deploy/verify.sh
```

3. **Play the steps in order.** Open `workshop/5spot-ctf-capd/step1-deploy/text.md`,
   run the commands, then run that step's `verify.sh`. Repeat for `step2…`, `step3…`.

That's it. **Stop the Codespace when you're done** (Code ▸ Codespaces ▸ Stop) so it
doesn't burn your free hours.

> Don't have the Codespace yet? On the repo: **Code ▸ Codespaces ▸ Create**, accept
> the offered machine, wait for the build, then run the steps above in its terminal.

## Good to know

- **kubectl shortcuts** — the pre-bake installs aliases (`k`, `kgp`, `ksm`,
  `kmgmt`, `kwl`, …). If a terminal you already had open doesn't have them, run
  `exec bash` (or open a new one). They live in `workshop/shared/kubectl-aliases.sh`.
- **State doesn't survive a rebuild** — rerun `make kind` if you restart the Codespace.
- *(Optional)* join the scoreboard so flags post themselves:
  `printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "team" "https://…" > ~/.flagboard`
- Want the **real** k0smotron track? It needs an SSH target — see [hard-setup.md](hard-setup.md).

## More

New to the game → **[user-guide.md](user-guide.md)** · not into CTF →
**[lab-guide.md](lab-guide.md)** · compare environments →
**[quickstart-tiers.md](quickstart-tiers.md)** · 5-Spot docs →
[5spot.finos.org](https://5spot.finos.org/) ·
**Facilitator** (hosting, prebuilds, cost) →
[codespaces-setup-facilitator.md](codespaces-setup-facilitator.md)
