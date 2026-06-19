#!/usr/bin/env python3
"""flagboard.py — zero-dependency flag API + live wallboard for the 5-Spot CTF.

Run it (laptop or any box with python3 — no pip installs):
    python3 leaderboard/flagboard.py                 # http://0.0.0.0:5050
    FLAGBOARD_PORT=8080 python3 leaderboard/flagboard.py

Endpoints:
    GET  /            live scoreboard (keep this on the projector; auto-refreshes)
    POST /api/flag    {"player": "...", "flag": "FLAG{...}", "step": "..."}
    GET  /api/scores  raw JSON

Valid flags are read LIVE from workshop/*/*/verify.sh at startup (same single
source of truth as everything else — `make salt-flags` just works; restart after
salting). Unknown flags are rejected unless FLAGBOARD_ALLOW_ANY=1.

Storage: SQLite next to this file (flagboard.db). Duplicate (player, flag)
submissions are ignored, so the verify.sh auto-post can fire repeatedly.
"""
import json, os, re, sqlite3, time
from http.server import HTTPServer, BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DB = os.environ.get("FLAGBOARD_DB", str(HERE / "flagboard.db"))
PORT = int(os.environ.get("FLAGBOARD_PORT", "5050"))
ALLOW_ANY = os.environ.get("FLAGBOARD_ALLOW_ANY") == "1"

def load_flags():
    flags = set()
    for f in ROOT.glob("workshop/*/*/verify.sh"):
        flags |= set(re.findall(r"FLAG\{[A-Z0-9_]+\}", f.read_text()))
    return flags

VALID = load_flags()

def points(flag):
    if "CONFIDENTIAL" in flag: return 200
    if "GITOPS" in flag: return 150
    return 100

def db():
    return sqlite3.connect(DB, timeout=10)

def init_db():
    c = db()
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("""CREATE TABLE IF NOT EXISTS captures(
        player TEXT, flag TEXT, step TEXT, points INT, ts REAL,
        UNIQUE(player, flag))""")
    c.commit(); c.close()

PAGE = """<!doctype html><html><head><meta charset="utf-8">
<title>5-Spot CTF — Reclaim the Idle</title>
<style>
 :root{--navy:#1E2761;--ice:#CADCFC;--teal:#2EC4B6;--amber:#F4A259;--card:#27336E}
 body{background:var(--navy);color:#fff;font-family:system-ui,Segoe UI,Helvetica,Arial,sans-serif;margin:0;padding:2rem 3rem}
 h1{font-size:2.6rem;margin:0 0 .2rem} h1 span{color:var(--teal)}
 .sub{color:var(--ice);margin-bottom:1.6rem}
 table{width:100%;border-collapse:collapse;font-size:1.5rem}
 th{color:var(--ice);text-align:left;font-weight:600;padding:.4rem .8rem;border-bottom:2px solid var(--card)}
 td{padding:.55rem .8rem;border-bottom:1px solid var(--card)}
 tr:first-child td{font-size:1.9rem}
 .pts{color:var(--teal);font-weight:800;text-align:right}
 .flags .chip{display:inline-block;background:var(--card);border-radius:999px;padding:.15rem .7rem;
   margin:.1rem .2rem;font-size:1rem;color:var(--ice)}
 .chip.b1{background:var(--teal);color:var(--navy);font-weight:700}
 .chip.b2{background:var(--amber);color:var(--navy);font-weight:700}
 .ticker{position:fixed;bottom:0;left:0;right:0;background:var(--card);color:var(--ice);
   padding:.5rem 3rem;font-size:1.1rem;white-space:nowrap;overflow:hidden}
 .crown{font-size:1.6rem}
 .empty{color:var(--ice);font-size:1.4rem;padding:3rem 0}
</style></head><body>
<h1>🏁 Reclaim the Idle <span>— live scoreboard</span></h1>
<div class="sub">5-Spot workshop · flags post automatically when your verifier goes green · docs: 5spot.finos.org</div>
<div id="board" class="empty">Waiting for the first capture…</div>
<div class="ticker" id="ticker"></div>
<script>
const NAMES = f => f.includes("CONFIDENTIAL") ? ["⭐⭐ CoCo","b2"] :
                f.includes("GITOPS") ? ["⭐ Flux","b1"] :
                f.includes("WINDOW")||f.includes("REMOTE_WORKER") ? ["1 window",""] :
                f.includes("RIDES_SPOT") ? ["2 taint",""] :
                f.includes("DRAIN") ? ["3 drain",""] : ["flag",""];
async function tick(){
  const r = await fetch("/api/scores"); const d = await r.json();
  if(d.scores.length){
    let html = "<table><tr><th></th><th>player / team</th><th>flags</th><th style='text-align:right'>points</th></tr>";
    d.scores.forEach((s,i)=>{
      const chips = s.flags.map(f=>{const [n,c]=NAMES(f);return `<span class="chip ${c}">${n}</span>`}).join("");
      html += `<tr><td class="crown">${i==0?"👑":i+1}</td><td>${s.player}</td><td class="flags">${chips}</td><td class="pts">${s.points}</td></tr>`;
    });
    document.getElementById("board").outerHTML = `<div id="board">${html}</table></div>`;
  }
  const t = d.recent.map(r=>`🏁 ${r.player} captured ${NAMES(r.flag)[0]}`).join("   ·   ");
  document.getElementById("ticker").textContent = t || "No captures yet — the window is open…";
}
tick(); setInterval(tick, 3000);
</script></body></html>"""

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, ctype="application/json"):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/":
            return self._send(200, PAGE, "text/html; charset=utf-8")
        if self.path == "/api/scores":
            c = db()
            rows = c.execute("SELECT player, flag, points, ts FROM captures ORDER BY ts").fetchall()
            players = {}
            for pl, fl, pt, ts in rows:
                p = players.setdefault(pl, {"player": pl, "points": 0, "flags": [], "last": 0})
                p["points"] += pt; p["flags"].append(fl); p["last"] = ts
            scores = sorted(players.values(), key=lambda p: (-p["points"], p["last"]))
            recent = [{"player": r[0], "flag": r[1]} for r in rows[-6:]][::-1]
            return self._send(200, json.dumps({"scores": scores, "recent": recent}))
        self._send(404, '{"error":"not found"}')

    def do_POST(self):
        if self.path != "/api/flag":
            return self._send(404, '{"error":"not found"}')
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            player = str(body.get("player", "")).strip()[:40]
            flag = str(body.get("flag", "")).strip()
            step = str(body.get("step", ""))[:40]
        except Exception:
            return self._send(400, '{"error":"bad json"}')
        if not player or not re.fullmatch(r"FLAG\{[A-Z0-9_]+\}", flag):
            return self._send(400, '{"error":"need player and FLAG{...}"}')
        if VALID and flag not in VALID and not ALLOW_ANY:
            return self._send(400, '{"error":"unknown flag"}')
        for attempt in (1, 2, 3):
            c = db()
            try:
                c.execute("INSERT INTO captures VALUES(?,?,?,?,?)", (player, flag, step, points(flag), time.time()))
                c.commit()
                return self._send(200, json.dumps({"ok": True, "points": points(flag)}))
            except sqlite3.IntegrityError:
                return self._send(200, '{"ok": true, "duplicate": true}')
            except sqlite3.OperationalError:
                time.sleep(0.1 * attempt)   # locked — brief retry
            finally:
                c.close()
        return self._send(503, '{"error":"busy, retry"}')

if __name__ == "__main__":
    init_db()
    print(f"flagboard: {len(VALID)} valid flags loaded "
          f"({'ANY accepted' if ALLOW_ANY else 'strict'}) — http://0.0.0.0:{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
