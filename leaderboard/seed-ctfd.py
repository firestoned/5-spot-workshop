#!/usr/bin/env python3
"""Seed a CTFd instance with the 5-Spot workshop challenges.

Flags are read live from workshop/*/*/verify.sh so the leaderboard can never
drift from the verifiers (including after `make salt-flags`).

Usage:
  1. Bring CTFd up (make leaderboard-up), finish the setup wizard in the browser.
  2. Admin panel -> Settings -> Access Tokens -> generate a token.
  3. CTFD_URL=http://localhost:8000 CTFD_TOKEN=ctfd_xxx python3 leaderboard/seed-ctfd.py
"""
import json, os, re, sys, urllib.request
from pathlib import Path

URL = os.environ.get("CTFD_URL", "http://localhost:8000").rstrip("/")
TOKEN = os.environ.get("CTFD_TOKEN") or sys.exit("set CTFD_TOKEN (Admin → Settings → Access Tokens)")
ROOT = Path(__file__).resolve().parent.parent

def flags_from(*globs):
    out = []
    for g in globs:
        for f in ROOT.glob(g):
            out += re.findall(r"FLAG\{[A-Z0-9_]+\}", f.read_text())
    return sorted(set(out))

CHALLENGES = [
    dict(name="Flag 1 — Open the window", value=100, category="core",
         description="Apply the ScheduledMachine and get the scheduled worker to join the workload cluster and go Ready.\n\nDocs: https://5spot.finos.org/concepts/scheduled-machine/",
         flags=flags_from("workshop/*/step1-deploy/verify.sh")),   # both CAPD + k0smotron variants accepted
    dict(name="Flag 2 — Stay compliant", value=100, category="core",
         description="Prove only taint-tolerating workloads ride the spot node.\n\nDocs: https://5spot.finos.org/concepts/",
         flags=flags_from("workshop/*/step2-taint/verify.sh")),
    dict(name="Flag 3 — Survive the drain", value=100, category="core",
         description="Close the window; graceful cordon→drain→delete to phase Inactive.\n\nDocs: https://5spot.finos.org/concepts/machine-lifecycle/",
         flags=flags_from("workshop/*/step3-drain/verify.sh")),
    dict(name="⭐ Bonus — GitOps with Flux", value=150, category="bonus",
         description="The ScheduledMachine is reconciled by a Flux Kustomization, not kubectl apply.",
         flags=flags_from("workshop/*/step4-flux-bonus/verify.sh")),
    dict(name="⭐⭐ Bonus — Confidential Containers", value=200, category="bonus",
         description="A sensitive workload runs in a TEE/microVM ON the reclaimable spot node (k0smotron track; needs /dev/kvm).",
         flags=flags_from("workshop/*/step5-coco/verify.sh")),
]

def api(method, path, payload=None):
    req = urllib.request.Request(URL + "/api/v1" + path, method=method,
        data=json.dumps(payload).encode() if payload else None,
        headers={"Authorization": "Token " + TOKEN, "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)

existing = {c["name"] for c in api("GET", "/challenges?view=admin")["data"]}
for ch in CHALLENGES:
    if not ch["flags"]:
        print(f"  ! no flags found for {ch['name']} — skipping"); continue
    if ch["name"] in existing:
        print(f"  = exists: {ch['name']}"); continue
    made = api("POST", "/challenges", dict(name=ch["name"], category=ch["category"],
        description=ch["description"], value=ch["value"], type="standard", state="visible"))
    cid = made["data"]["id"]
    for fl in ch["flags"]:
        api("POST", "/flags", dict(challenge_id=cid, content=fl, type="static"))
    print(f"  + created: {ch['name']}  ({len(ch['flags'])} accepted flag(s), {ch['value']} pts)")
print("\nDone. Scoreboard: " + URL + "/scoreboard")
