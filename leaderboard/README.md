# Leaderboard — flag submission via QR code

Players capture `FLAG{…}` strings; this is where they post them. Three options,
cheapest-ops first.

## Option A (recommended): the built-in flagboard — auto-posting + live wallboard

`flagboard.py` is a single-file, zero-dependency (python3 stdlib) flag API with a
projector-ready live scoreboard. Its killer feature: **flags post themselves** —
every `verify.sh` carries a fire-and-forget hook, so the moment a player's CHECK
goes green, their capture appears on the monitor. No manual pasting.

```bash
make flagboard                                   # wallboard + API on :5050
make leaderboard-tunnel PORT=5050                # free public https URL (keep terminal open)
make qr URL=https://xxxx.trycloudflare.com OUT=slides/qr-leaderboard.png
```

Players join once (the scenario intros show this):

```bash
printf 'PLAYER=%s\nFLAGBOARD_URL=%s\n' "team-name" "https://xxxx.trycloudflare.com" > ~/.flagboard
```

From then on captures auto-post; the QR is only needed for that one join command
(and for spectators to watch the board on their phones). Mechanics:

- Valid flags load **from the `verify.sh` files at startup** — `make salt-flags`
  stays in sync (restart the board after salting). Unknown flags are rejected.
- Duplicates ignored, so re-running a verifier is harmless. Points 100/100/100,
  ⭐150, ⭐⭐200, ranked with a 👑 and a recent-captures ticker.
- The hook never fails a verifier: 3-second timeout, `|| true`, and silently does
  nothing if `~/.flagboard` is absent.
- Storage is `leaderboard/flagboard.db` (SQLite/WAL, fine for a room-sized burst).
- Keep the page open full-screen on the projector — it refreshes every 3s.

## Option B: self-hosted CTFd + free Cloudflare tunnel

[CTFd](https://github.com/CTFd/CTFd) is the standard open-source CTF platform —
flag validation, scoreboard, teams, and it's free to self-host. The hosted
ctfd.io free tier only fits ~10 players, so for a workshop room you self-host.
You don't even need a VM: run it on the presenter laptop and expose it with a
free Cloudflare quick tunnel (no account needed).

```bash
make leaderboard-up                      # CTFd at http://localhost:8000
# → open it, finish the setup wizard (event name, admin account, "Teams" or "Users" mode)
# → Admin Panel ▸ Settings ▸ Access Tokens ▸ generate
make leaderboard-seed CTFD_TOKEN=ctfd_xxxxx
make leaderboard-tunnel                  # prints a public https://….trycloudflare.com URL
make qr URL=https://xxxx.trycloudflare.com OUT=slides/qr-leaderboard.png
```

Drop `slides/qr-leaderboard.png` onto the deck's game slide (and print a couple
for the tables). Players scan → register → paste flags → scoreboard does the rest.

Notes:
- The seeder reads flags **directly from the `verify.sh` files**, so the
  leaderboard can never drift from the verifiers. Flag 1 accepts both the CAPD
  and k0smotron variants. Points: 100/100/100, ⭐150, ⭐⭐200.
- Quick tunnels get a random URL per run — start the tunnel **before** printing
  QR codes, and keep that terminal open all day. For a stable URL, a named
  Cloudflare tunnel (free account) or a ~€5 VM running the same compose file works.
- Want a dry run? `make leaderboard-up && make leaderboard-seed CTFD_TOKEN=…`
  the week before takes 10 minutes.

## The flags-are-public problem (read this)

This repo is public, so the flag strings are readable on GitHub. For bragging
rights that's fine — but if you want the leaderboard to mean something:

```bash
make salt-flags SALT=OSFF26     # FLAG{X} → FLAG{X_OSFF26} in every verify.sh
make leaderboard-seed CTFD_TOKEN=…   # re-seed; stays in sync automatically
```

Do this on the morning of the event (then re-publish the browser lab / re-run the
pre-bake), and the GitHub-visible flags from yesterday no longer validate.

## Option B: ctfd.io hosted free tier

Zero ops, but realistically sized for ~10 participants — fine for a dry run or a
tiny session, too small for the room. Paid tiers exist if budget appears.

## Option C (zero-ops fallback): Google Form + Sheet

Create a Form with Name / Team / Flag / Which challenge, QR the form link
(`make qr URL=<form-url>`), and project the linked response Sheet sorted by
timestamp as the "scoreboard". No validation, pure honor system — but it cannot
break, needs nothing installed, and works on any phone. Good plan-B to have in
your pocket even if you run CTFd.
