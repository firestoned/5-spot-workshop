# 🟢 Killercoda tier — jump in (zero install)

You chose the browser. Nothing to install, nothing to configure — the cluster
pre-bakes itself while you read the intro.

## Jump in

1. Open the scenario link your facilitator shared:
   - **Simplified (CAPD)** — learn the lifecycle fast; explicitly *not* a
     real-world setup.
   - **Real (k0s + k0smotron)** — the production-representative track.
2. Press **START**. Pre-bake takes ~2–5 minutes; watch it with
   `tail -f /opt/5spot-setup.log` if you're curious.
3. *(Optional, 10s)* Join the live scoreboard — run the one-liner from the intro
   with your team name and the URL from the QR on screen. After that your flags
   post themselves.
4. Work each step; every command block is click-to-run. Press **CHECK** when you
   think you've got it — green means flag captured, and the hints on red are the
   fastest way to debug.

## Tier-specific gotchas

- **Sessions expire** (free-tier time limits). If yours dies, relaunch the link —
  pre-bake re-runs automatically. Your scoreboard flags are already banked.
- **Don't fight the clock at the start**: if `kubectl get sm -A` errors, the
  pre-bake simply isn't done yet. Watch the log; grab a coffee.
- The k0smotron scenario is heavier; if it struggles on the free backend, do the
  CAPD track here and the real track in [Codespaces](codespaces-setup.md) or
  [locally](hard-setup.md).

## Help

Failing CHECK hints → [Troubleshooting](https://5spot.finos.org/operations/troubleshooting/)
→ your table → the facilitator. Game rules: [user-guide.md](user-guide.md).
No-game version: [lab-guide.md](lab-guide.md).
