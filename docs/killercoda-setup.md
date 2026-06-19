# Killercoda Setup — host the workshop in the browser (free)

[Killercoda](https://killercoda.com) runs interactive scenarios in the browser from
a **public GitHub repo**. It's free for public scenarios, and its **CHECK** button
runs a verifier script per step — which is exactly our CTF flag mechanic. This guide
gets the two scenarios in this repo live.

## 1. Accounts & repo

1. Sign in to https://killercoda.com with GitHub.
2. Go to **Account → Creators** (https://killercoda.com/creators) and connect this
   repository (your published `5-spot-workshop`). Killercoda watches a branch and
   **re-deploys on every push** — no manual upload.
3. Each scenario is a directory containing an `index.json`. This repo ships two:
   - `workshop/5spot-ctf-capd/` — 🟢 simplified (Docker provider)
   - `workshop/5spot-ctf-k0smotron/` — 🔵 real (k0s + k0smotron, RemoteMachine/SSH)

   In the creator UI, add each as a scenario and point it at that path.

## 2. How a scenario is wired

`index.json` is the whole contract:

```jsonc
{
  "title": "...",
  "details": {
    "intro":  { "text": "intro.md", "background": "setup-background.sh" },
    "steps":  [ { "title": "...", "text": "step1-deploy/text.md", "verify": "step1-deploy/verify.sh" } ],
    "finish": { "text": "finish.md" }
  },
  "backend":   { "imageid": "ubuntu" },
  "interface": { "layout": "terminal" }
}
```

- **`background`** runs *before* the user starts, hidden — this is our pre-bake.
- **`verify`** runs when the user clicks **CHECK**; exit `0` = pass (flag awarded),
  non-zero = "not yet" with hints.
- Inline `{{exec}}` after a fenced command makes it click-to-run in the terminal.
- We also `git clone` finos/5-spot inside the background script for the live
  `deploy/` manifests.

> **⚠️ Gotcha — `background`/`verify` scripts do NOT run from the scenario dir.**
> Killercoda copies them to `/var/run/kc-internal/` and runs them there, so
> `$(dirname "$0")/assets` is **empty** — anything `$0`-relative breaks (this is
> what crashed an early pre-bake). To get the scenario's `assets/*.yaml` onto the
> VM you must declare them in the **`assets`** block of `index.json`:
>
> ```jsonc
> "assets": {
>   "host01": [
>     { "file": "assets/*.yaml",      "target": "/root/5spot-workshop" },
>     { "file": "assets/flux/*.yaml", "target": "/root/5spot-workshop/flux" }
>   ]
> }
> ```
>
> Killercoda stages those to `host01` before the background script runs. Both
> scenarios here also keep a **fallback**: if the manifests aren't staged, the
> background script shallow-clones the workshop repo (`WORKSHOP_REPO_URL`, default
> the public repo) and copies `workshop/<scenario>/assets/` itself — so a run never
> depends on `$0` being next to `assets/`. (`text.md` files referenced in
> `index.json` *are* rendered directly; it's only sibling asset files that need
> staging.)

Reference: https://killercoda.com/creators

## 3. Choosing the backend (`imageid`)

| `imageid` | Gives you | Use for |
|-----------|-----------|---------|
| `ubuntu` | single Ubuntu VM with Docker | **CAPD scenario** — kind + Docker provider. |
| `ubuntu` (2 nodes) | `node01` + `node02`, mutually reachable on fixed IPs | **k0smotron scenario** — `node01` runs the kind mgmt cluster; `node02` is the **RemoteMachine SSH target** a worker is provisioned onto. |

For the multi-node layout, set the environment to two Ubuntu nodes in the creator
UI. The background script wires an SSH key from the mgmt cluster to `node02` and
points the `RemoteMachine` at `node02`'s IP — a genuinely "real" remote provisioning
flow, no cloud account needed.

## 4. ⚠️ Resource & time reality check (do this first)

kind + CAPD spins ~4 Docker containers; the k0smotron path adds k0smotron
controllers + a hosted control plane + a remote worker. Free Killercoda envs are
modest on RAM and have session time limits. **Before committing, smoke-test:**

```bash
# In a fresh Killercoda ubuntu env, paste the background script and time it:
time bash setup-background.sh
docker ps          # confirm the expected containers are up
free -h            # headroom left?
```

If the pre-bake busts the budget (OOM, or doesn't finish before the session
expires), fall back for the **Easy** tier to either:
- a **pre-baked VM image** you snapshot once and clone per attendee (Hetzner/Civo
  have low-latency London regions and hourly billing), or
- **GitHub Codespaces** with a devcontainer (the Medium tier).

The k0smotron scenario is the more likely to exceed limits — keep it as the
**self-hosted / local** real path and treat Killercoda as best-effort there.

> **⏱️ Session time limits are per-USER, not per-scenario — you can't extend them
> from `index.json`.** Killercoda caps an environment at **1 hour on FREE** and
> **4 hours on PLUS** (~$9.99/mo). The cap follows the *attendee's* membership, not
> the creator's, so there is **no scenario field** to lengthen it. When the timer
> ends the environment is destroyed and the user must reload for a **fresh** one —
> **all cluster state is lost** (PLUS also allows 3 concurrent envs vs FREE's 1).
>
> Planning consequences:
> - Assume most attendees are on **FREE = 60 minutes**. The 🟢 **Easy (CAPD)** run
>   must finish — pre-bake *plus* all three flags — inside that window. Smoke-test
>   end-to-end against a 60-min budget, not just "does it boot".
> - The 🔵 **REAL (k0smotron)** scenario won't comfortably fit 60 min; it needs
>   attendees on **PLUS (4h)** *or* a non-Killercoda tier.
> - Need a guaranteed multi-hour run for **everyone**? Use a tier with **no
>   Killercoda timer**: **Codespaces**, **local kind**, or the **pre-baked VM**
>   fallback above — those run as long as you want.
> - Seeing "60 / 120 min" while paying for PLUS? Make sure you're **signed into the
>   PLUS account** in that browser (60 min is the FREE cap); the number on a course
>   card can also be a descriptive *estimate*, distinct from the real plan-based cap.

## 5. Test locally before pushing

You don't need to push to iterate. Killercoda renders straight Markdown, and the
scripts are plain bash:

```bash
# Validate structure
python3 -c "import json; json.load(open('workshop/5spot-ctf-capd/index.json'))"
bash -n workshop/5spot-ctf-capd/setup-background.sh
bash -n workshop/5spot-ctf-capd/*/verify.sh
```

Then push to your watched branch; Killercoda updates within seconds.

## 6. Leaderboard / teams

Killercoda tracks per-user step completion. For a shared **team** scoreboard, run a
side channel (a shared doc, or the minimal scoreboard in the repo roadmap) and have
teams paste their captured `FLAG{...}` strings. Solo players just use CHECK.

---

Need help with the 5-Spot side of any step? Link out to the docs:
[Quick Start](https://5spot.finos.org/installation/quickstart/) ·
[ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/) ·
[Machine Lifecycle](https://5spot.finos.org/concepts/machine-lifecycle/) ·
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/)
