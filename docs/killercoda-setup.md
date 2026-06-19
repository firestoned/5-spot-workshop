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
   - `killercoda/5spot-ctf-capd/` — 🟢 simplified (Docker provider)
   - `killercoda/5spot-ctf-k0smotron/` — 🔵 real (k0s + k0smotron, RemoteMachine/SSH)

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
- Files in the scenario dir are available in the environment; we also `git clone`
  finos/5-spot inside the background script for the live `deploy/` manifests.

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

## 5. Test locally before pushing

You don't need to push to iterate. Killercoda renders straight Markdown, and the
scripts are plain bash:

```bash
# Validate structure
python3 -c "import json; json.load(open('killercoda/5spot-ctf-capd/index.json'))"
bash -n killercoda/5spot-ctf-capd/setup-background.sh
bash -n killercoda/5spot-ctf-capd/*/verify.sh
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
