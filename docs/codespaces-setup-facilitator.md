# 🟡 Codespaces tier — facilitator setup

How to host the **Medium tier** on GitHub Codespaces: every attendee gets a cloud
devbox with the pinned toolchain pre-installed, then runs the cluster bring-up
themselves. This is the best tier for **Windows users** and anyone who can't (or
won't) install Docker locally, and a codespace runs until it idles out or you stop
it (no short session timer).

> Attendee-facing instructions live in [codespaces-setup.md](codespaces-setup.md).
> This doc is for **you, the facilitator**: accounts, prebuilds, machine-type and
> cost policy, and the pre-event smoke test.

---

## 0. TL;DR

```bash
make codespaces        # validates .devcontainer + prints the go-live steps
```

1. Push this repo **public** (or share a repo attendees can read).
2. (Strongly recommended) **Enable prebuilds** so the container is ready in seconds, not minutes.
3. Decide **who pays** (attendee free quota vs. org-sponsored) and set a spending limit.
4. Smoke-test one codespace end-to-end (§5) the week before.
5. Day-of: attendees do **Code ▸ Codespaces ▸ Create on main** → 4-core → `make kind`.

---

## 1. What attendees get (the devcontainer)

Defined entirely in [`.devcontainer/`](../.devcontainer/) — no per-attendee setup:

- **Base image** `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
- **Features**: docker-in-docker, plus `kubectl 1.31.0` + `helm` (latest)
- **`post-create.sh`** pins the rest: `kind v0.24.0`, **`clusterctl v1.9.5`**
  (the v1beta1-compatible line 5-Spot needs), and `flux`
- **`hostRequirements: { cpus: 4, memory: 16gb }`** — Codespaces won't start a
  machine smaller than this, so the 2-core default that can't hold
  kind + CAPI + a workload cluster is **off the table automatically**. We pin **4**,
  not 8, deliberately: **8-core+ machines aren't available on a free account**
  (they need billing set up), so requiring 8 produces *"no machine types
  available."* 4-core / 16 GB is the largest free machine and it's plenty for the
  CAPD scenario (the controller's CPU request is already trimmed to fit).

Validate all of that before an event with `make codespaces` (checks the JSON,
the script syntax, and presence) — run it in CI too.

---

## 2. Accounts & repo wiring

1. **The repo must be readable by attendees.** Public is simplest; a private repo
   works only if every attendee is a member/collaborator. Anyone who can read the
   repo can create a codespace **on it** (owned by and billed to *them*) — they do
   **not** need to fork.
2. **Codespaces must be enabled** for wherever the repo lives:
   - *Personal/public repo* → Codespaces is on by default for the creator.
   - *Org-owned repo* → **Org ▸ Settings ▸ Codespaces ▸ enable**, and pick which
     members/repos can use it.
3. **Confirm the devcontainer is on the default branch** (`main`). Codespaces reads
   `.devcontainer/` from the branch the codespace is created on.

> **💸 The zero-cost path (no GitHub bill for you).** Keep the repo **public** and
> let attendees **self-serve** — each codespace is billed to *their own* free
> monthly quota, not to you or the org. You pay nothing. The catch on an
> **org-owned repo (like `github.com/firestoned/…`) on the Free plan**: repo-level
> Codespaces settings and **prebuilds are unavailable** (they need GitHub Team or
> Enterprise + billing — see §3). That only costs you the prebuild *speed*
> optimization; **public-repo codespaces still work for attendees without any paid
> plan.** If you ever want free prebuilds without paying for Team, host the repo
> under a **personal account** instead. Bottom line: you do **not** have to pay to
> run this tier — just expect the first container build to take a few minutes
> (§3 has the stagger-the-starts mitigation).

---

## 3. Prebuilds (do this — it's the difference between 30 s and 6 min)

Without a prebuild, each attendee waits for the image pull + `post-create.sh`
(downloads kind/clusterctl/flux) — several minutes, multiplied across the room and
hammering the same endpoints. A **prebuild** bakes the container ahead of time so
creation is near-instant.

> **⚠️ Whether you even *have* a "Codespaces" entry in repo Settings depends on who
> owns the repo:**
> - **Personal-account repo** → prebuilds are **available for free**. You just need
>   **Actions enabled** on the repo and a Codespaces **spending limit** set on your
>   account (Settings ▸ Billing ▸ Codespaces).
> - **Organization-owned repo** (e.g. `github.com/firestoned/…`) → repo-level
>   Codespaces settings, **including prebuilds, only appear on GitHub Team or
>   Enterprise** orgs *with* a payment method + Codespaces spending limit. On a
>   **Free org the "Codespaces" settings page is hidden entirely** — that's why you
>   don't see it.
>
> So if the prebuild UI is missing: either **upgrade the org to Team** (~$4/user/mo)
> and set a Codespaces spending limit, or **host the workshop repo under a personal
> account** (prebuilds are free there). Or skip prebuilds — see the note below.

Set it up once (when available): **Repo ▸ Settings ▸ Code and automation ▸
Codespaces ▸ Set up prebuild**
- **Branch**: `main`
- **Region(s)**: pick where attendees are (e.g. West Europe for a London room) —
  prebuilds are per-region.
- **Trigger**: on push to `main` (the default) so it refreshes when you edit the devcontainer.
- It runs as a GitHub Actions workflow and consumes a little Actions + storage
  budget. Worth it.

After it succeeds, the machine-type picker shows a **"Prebuild ready"** ⚡ badge.
Re-run/verify the prebuild after **any** change to `.devcontainer/`.

> **Prebuilds are an optimization, not a requirement.** Without one, attendees can
> still create codespaces on the public repo (billed to *their own* quota, since
> creation cost follows the creator, not the repo owner) — the container just
> builds fresh (~a few minutes via `post-create.sh`). If you can't prebuild, warn
> attendees the first build takes a few minutes and **stagger their starts** so the
> tool downloads don't thundering-herd.

---

## 4. Who pays, machine types & spending limits

Codespaces compute is **billed to the owner of the codespace**:

| Model | Who pays | When to use |
|-------|----------|-------------|
| **Attendee self-serve** (default) | Each attendee's personal GitHub quota | Public repo, attendees have GitHub accounts. Simplest — zero facilitator cost. |
| **Org-sponsored** | Your org, under a spending limit | Locked-down cohort, guaranteed capacity, you don't want to rely on personal quotas. |

**Free quota (self-serve):** personal accounts include a monthly pool of core-hours
+ storage (commonly ~120 core-hours on GitHub Free, more on Pro). On the **4-core**
machine that's roughly **~30 hours of run time** — ample for a 2.5-hour workshop,
*if they stop the codespace afterwards*. Always tell attendees to **stop** it
(Code ▸ Codespaces ▸ Stop) when done. Confirm current numbers at
<https://docs.github.com/billing/managing-billing-for-github-codespaces>.

> **Why 4-core, not 8:** free accounts (personal *and* Free orgs) are only offered
> machine types up to **4-core / 16 GB** — 8-core+ requires a payment method /
> spending limit. Requiring 8 in `hostRequirements` yields *"no machine types
> available."* If you (or attendees) set up billing, you can bump
> `hostRequirements` back to `cpus: 8` for more headroom.

**Org-sponsored knobs** (Org ▸ Settings ▸ Codespaces):
- **Spending limit** — set a hard cap so a forgotten codespace can't run up a bill.
- **Machine-type policy** — you can *restrict* available sizes; pair with the
  devcontainer's `hostRequirements` to pin everyone to a chosen size (and, with
  billing, unlock 8-core+).
- **Idle timeout & retention** — default idle stop is 30 min; lower it (e.g. 15 min)
  for an event so abandoned codespaces stop sooner. Set retention to auto-delete
  after a day or two so storage doesn't linger.

---

## 5. Pre-event smoke test (do this the week before)

Create one codespace exactly as an attendee would and run the whole flow:

```bash
# inside the codespace terminal
./scripts/5-spot-bootstrap.sh --env-tier codespaces   # verifies the pinned tools
time make kind                                         # full CAPD pre-bake (~5–10 min)
bash workshop/5spot-ctf-capd/step1-deploy/verify.sh    # flag 1 should pass
```

Check:
- `make kind` finishes well inside the time you'll give attendees.
- `docker ps` shows the kind mgmt + CAPD workload containers; `free -h` has headroom.
- All three CAPD verifiers go green.
- If you enabled a prebuild, also confirm **creation** is fast (the ⚡ badge).

Re-run this after any change to `.devcontainer/` or the scenario `setup-background.sh`.

---

## 6. Day-of attendee flow (what they'll do)

Point them at [codespaces-setup.md](codespaces-setup.md). In short:

1. **Code ▸ Codespaces ▸ Create codespace on main** → **4-core / 16 GB**
   (the devcontainer enforces the floor; with a prebuild it's instant).
2. `./scripts/5-spot-bootstrap.sh --env-tier codespaces` then `make kind`.
3. Optional scoreboard join:
   `printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "team" "https://…" > ~/.flagboard`
4. Play `workshop/5spot-ctf-capd/step*/text.md`, running each `verify.sh` to capture flags.

Everything runs **inside** the codespace (its terminal), not their laptop.

---

## 7. The REAL (k0smotron) track in Codespaces

The Medium tier targets the 🟢 **CAPD** scenario. The 🔵 k0smotron track *can* run
in a codespace but needs an SSH **RemoteMachine** target, and "localhost-as-target
inside a codespace" is unvalidated. For the real track, prefer **local/Hard** or a
**pre-baked cloud VM** — see [hard-setup.md](hard-setup.md) §RemoteMachine. Treat
k0smotron-on-Codespaces as best-effort.

---

## 8. Teardown & cost hygiene (after the event)

- Remind attendees to **Stop** (preserves the codespace, halts the meter) or
  **Delete** (frees storage) — Code ▸ Codespaces, or <https://github.com/codespaces>.
- Org-sponsored: confirm the spending-limit graph flattens after the event; delete
  lingering org codespaces; consider disabling Codespaces for the repo until next time.
- Nothing to clean in *this* repo — codespace state is per-attendee and ephemeral.

---

## 9. Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| **No "Codespaces" entry in repo Settings** | The repo is **org-owned on a Free org** — repo-level Codespaces/prebuild settings need Team/Enterprise + billing. Upgrade the org, or host under a personal account. Codespaces still *work* for attendees regardless. See §3. |
| Codespace creation is slow every time | No prebuild, or prebuild not in the attendee's region. See §3. |
| `no machine types are available` at create time | `hostRequirements` asks for more than a free account offers. Free accounts cap at **4-core**; the devcontainer pins `cpus: 4`. If you reintroduced `cpus: 8`, either set up billing or drop back to 4. |
| "Insufficient resources" / pods Pending during `make kind` | 4-core is tight for heavy workloads. The 5spot-controller request is already trimmed; if other pods stay Pending, lower their requests too, or move the heavy (k0smotron) track off Codespaces. |
| `clusterctl` errors about `cluster.x-k8s.io/v1beta1` | Wrong clusterctl line. The pin is **v1.9.5**; rebuild the container so `post-create.sh` reinstalls it. |
| Tools present but cluster gone after restart | Expected — tools persist, cluster state doesn't. Re-run `make kind`. |
| Attendee burned their free quota | They left codespaces running. Stop unused ones; org-sponsor next time with a spending limit. |

## Help

[cli-setup.md](cli-setup.md) (tool details) ·
[iximiuz-setup.md](iximiuz-setup.md) (the browser-lab tier) ·
[Troubleshooting](https://5spot.finos.org/operations/troubleshooting/) ·
GitHub Codespaces docs: <https://docs.github.com/codespaces>
