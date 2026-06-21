# iximiuz Labs Setup — host the workshop as a skill path

[iximiuz Labs](https://labs.iximiuz.com) runs interactive content on real,
multi-node VM **playgrounds** (more headroom than browser-only sandboxes) with an
automated **task engine** that checks a learner's progress — a natural fit for our
CTF flag mechanic. This guide publishes the 5-Spot workshop there.

iximiuz content is pushed from your machine with the **`labctl`** CLI against your
**author account** (it does not watch a git repo).

## 1. Account & CLI

1. Sign in at https://labs.iximiuz.com. **Authoring requires a paid plan** — the
   **Complete Bundle** ("Pro: Creator and Trainer modes"). On the free tier,
   `labctl content create` fails with `402: Cannot create an author profile while on
   the free tier`, so publishing is blocked until you upgrade. (Everything in this
   repo is publish-ready; the only gate is the account tier.)
2. Install the CLI and authenticate:
   ```bash
   curl -sf https://labs.iximiuz.com/cli/install.sh | sh   # → ~/.iximiuz/labctl/bin (added to PATH)
   # or on macOS/Linux:  brew install labctl
   labctl auth login
   ```

## 2. What's in this repo

The content source lives under `iximiuz/`, laid out the way `labctl` expects
(`<kind>s/<name>/`):

```
iximiuz/
  skill-paths/5-spot-ctf/        # the course wrapper
    index.md                     #   kind: skill-path (intro)
    unit-10.md                   #   kind: unit → card to the CAPD challenge
    unit-20.md                   #   kind: unit → card to the k0smotron challenge
  challenges/
    5spot-ctf-capd/index.md      # 🟢 Docker provider — 4 flags
    5spot-ctf-k0smotron/index.md # 🔵 k0s + k0smotron — 5 flags
```

**How it maps to the `workshop/` scenarios** (single source of truth — we do *not*
duplicate the bring-up or verifier bash):

| `workshop/` scenario | iximiuz Labs |
|---|---|
| `setup-background.sh` pre-bake | a challenge **`init: true`** task that `git clone`s this repo and runs the *same* `workshop/.../setup-background.sh` |
| step `verify.sh` (flag) | a **regular task** that shells out to the *same* `workshop/.../verify.sh`; the header shows flags-complete = scoring |
| one multi-step scenario | one **multi-task challenge** (so all flags share one pre-baked cluster) |
| two scenarios | a **skill path** with two units, one card per challenge |

Because the init task clones `github.com/firestoned/5-spot-workshop` at runtime, the
published challenges always run the latest committed pre-bake/verifiers — **push the
repo public first**, then publish the content.

## 3. Choosing the playground

| Challenge | Base playground (`playground.name`) | Machines | Resources | Notes |
|-----------|-------------------------------------|----------|-----------|-------|
| CAPD (🟢) | `docker` | `docker-01` | 4 CPU / **10 GiB**, single node | Comfortable for kind + CAPD's ~4 sibling containers. Tasks need no `machine:`. |
| k0smotron (🔵) | `mini-lan-ubuntu-docker` | `node-01`…`node-04` | ~2 CPU / **4 GiB per node** | `node-01` = mgmt; `node-02` = `RemoteMachine` SSH target. Heavier — **best-effort** (same caveat the README gives the browser lab). |

Names and machine hostnames above are confirmed against the iximiuz playgrounds API
(`https://labs.iximiuz.com/api/playgrounds?filter=base`); `make iximiuz` re-checks
them. To re-verify on your account: `labctl playground list`.

## 4. Before publishing — what's confirmed, what to smoke-test

All format/wiring values are resolved and checked by `make iximiuz` (frontmatter
parses, playground names valid, challenge cards use the `:challenge:` key, every
referenced `workshop/.../*.sh` exists). No unresolved publish-time markers remain.

One thing still needs a **live smoke-test on your account** — it can't be validated
offline:

- **k0smotron RemoteMachine SSH on MiniLAN.** The CAPD challenge is solid. The
  k0smotron pre-bake provisions a k0s worker onto `node-02` over SSH: the init task
  passes `REMOTE_NODE_HOST=node-02`, and the script resolves that hostname → IP and
  pushes a generated key to `root@node-02`. This relies on `node-01` reaching
  `node-02` as root.

  The key-push uses `ssh -o BatchMode=yes -o ConnectTimeout=10`, so it **can no
  longer hang** if root SSH isn't passwordless — earlier it had no BatchMode and
  would block the init task forever (the playground sat in *"Warming up…"*). Now it
  fails fast, logs a warning, and the pre-bake **completes** so the playground
  starts. But if that key-push fails, **Flag 1 (the remote worker) won't provision**
  until you authorize the key on `node-02` manually. Whether MiniLAN allows
  passwordless root `node-01`→`node-02` SSH is the thing to confirm live.

  Reality check: k0smotron is the **hard/real** tier, designed for local/self-hosted
  runs. On the MiniLAN browser playground it's best-effort — if the remote-SSH or
  RAM constraints below bite, run k0smotron locally and keep **CAPD as the browser
  lab**. Watch a run with `tail -f /tmp/5spot-setup.log`.

Per-node RAM on MiniLAN (~4 GiB) is also tight for k0smotron; if it OOMs, keep the
k0smotron track as the local/self-hosted real path and run only CAPD in the browser.

## 5. Publish

One command does the whole flow — it installs `labctl` if missing, verifies you're
authenticated, then creates (first run) and pushes all three items:

```bash
make iximiuz-publish
```

Two interactive bits, both in a normal terminal (not pipeable/CI):

1. **Login** — `labctl auth login` opens a browser flow. Run it once first:
   ```bash
   labctl auth login          # one-time; then re-run make iximiuz-publish
   ```
2. **Create confirmation** — `labctl content create` asks a **y/N** per new item
   (there's no `--yes` flag, and `--quiet` still prompts). Answer **y** for each.
   The publish script does *not* suppress this prompt — if you ever see it appear to
   hang right after a `── kind/name ──` line, it's waiting for your `y`.

> Gotcha: `labctl auth whoami` exits 0 even when logged out, so the script gates on
> the "Not logged in" message, not the exit code. And `create` writes to `/dev/tty`
> directly, so it can't be auto-answered by piping — it needs a real terminal.

Under the hood (`scripts/iximiuz-publish.sh`), per item:
- **create** registers it server-side (tolerated if it already exists). It runs
  against a *throwaway copy* of the content, because `create` may scaffold/overwrite
  `index.md` in its `--dir` — we never point it at the real source.
- **push `--force`** uploads our authored files from the real dir and makes the
  remote match local exactly.

Manual equivalent, if you'd rather not use the wrapper (run from `iximiuz/`):

```bash
labctl content create challenge 5spot-ctf-capd --dir challenges/5spot-ctf-capd   # once → assigns a SUFFIXED slug
labctl content list | grep pageUrl                                               # find the real slug, e.g. 5spot-ctf-capd-f3d76f57
labctl content push challenge 5spot-ctf-capd-f3d76f57 --dir challenges/5spot-ctf-capd --force
# …repeat for 5spot-ctf-k0smotron and the 5-spot-ctf skill-path
```

> **`create` assigns a random-suffix slug** (`5spot-ctf-capd` → `…-f3d76f57`), so you
> must `push` to that *suffixed* slug — pushing to the base name 404s, and re-running
> `create` spawns a duplicate. The wrapper script resolves the existing slug from
> `content list` and pushes to it (idempotent), which is why it's the safer path.

> Tip: `labctl content push --watch` hot-reloads on save for a fast authoring loop.
> After install, add `~/.iximiuz/labctl/bin` to your PATH (the installer prints the
> exact line for your shell rc).

## 6. Find your content, smoke-test, then give it to students

**Slugs get a random suffix.** iximiuz assigns each item a globally-unique slug —
`5-spot-ctf` becomes e.g. `5-spot-ctf-dc5a4cf4`. There's no flag to control it, and
the *base* URL 404s. Get the real URLs anytime:

```bash
labctl content list | grep pageUrl
```

**Your content is PRIVATE.** Authored content is "visible only to the author" — the
URL returns **404 to everyone but you** (logged in as the owning account). So you
can't just paste a link to students; you grant access through a **Training** (below).

> If your authoring dashboard looks empty, you're logged into the website with a
> *different* identity than `labctl`. Content is owned by whoever `labctl auth whoami`
> reports — sign into the site with that **same** provider/account (e.g. the same
> GitHub login).

**Smoke-test first (do this).** Start the **CAPD challenge** yourself, let the init
task finish (the playground shows "loading" until the pre-bake completes — watch it
with `tail -f /opt/5spot-setup.log`), and confirm each flag flips to complete. The
flagboard scoreboard works here too — the verifiers self-post. The browser run is the
only real proof: `push` validates front matter, not that the live pre-bake/verifiers
work in the playground.

### Give it to students — a Training (Trainer mode)

Trainings are **web-UI only** (there is no `labctl training` command). Trainer mode
is a paid **instructor** feature, but **students join with free accounts** — no
upgrades, no paywall for them.

1. Open your **Trainer dashboard** → <https://labs.iximiuz.com/for-trainers>.
2. **Create a Training** and add the **5-Spot skill-path** (it bundles both the CAPD
   and k0smotron challenges — adding the skill-path makes both tracks available; the
   k0smotron unit carries its own draft/best-effort warning).
3. Set enrollment and copy the **join link** — *that* link is what you hand to
   students. (The skill-path's slug suffix is invisible to them.)
4. Students open the link, join free; you can track their progress — which pairs
   nicely with the flagboard.

**Alternative:** publish the content **publicly** from the web UI ("available to the
world"), after which the suffixed URL works for anyone. For a cohort a Training is
better (free students, enrollment, progress tracking, no public-catalog listing).

---

Need help with the 5-Spot side of any step?
[Quick Start](https://5spot.finos.org/installation/quickstart/) ·
[ScheduledMachine](https://5spot.finos.org/concepts/scheduled-machine/) ·
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/)
