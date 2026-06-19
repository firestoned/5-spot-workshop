#!/usr/bin/env bash
# =============================================================================
# test-tiers.sh — FACILITATOR ONLY. Automated validation of every tier.
#
#   ./scripts/test-tiers.sh                  # static checks for all tiers
#   ./scripts/test-tiers.sh --tier kind --live    # + actually boot the CAPD env (slow)
#   ./scripts/test-tiers.sh --tier k0smotron --live  # + boot k0smotron stack (slower)
#   ./scripts/test-tiers.sh --keep           # don't tear down live clusters after
#
# Static checks need only bash+python3. Live checks need docker (8GiB+).
# Exit code 0 = everything passed.
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

TIER=all; LIVE=false; KEEP=false
while [ $# -gt 0 ]; do case "$1" in
  --tier) TIER="$2"; shift 2;;
  --live) LIVE=true; shift;;
  --keep) KEEP=true; shift;;
  *) echo "usage: $0 [--tier all|killercoda|codespaces|kind|k0smotron] [--live] [--keep]"; exit 2;;
esac; done

PASS=0; FAIL=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; FAIL=$((FAIL+1)); }
section(){ printf '\n━━ %s ━━\n' "$*"; }

# ---------- shared static checks ---------------------------------------------
static_repo() {
  section "Repo hygiene"
  [ -f README.md ] && ok "README.md" || bad "README.md missing"
  for f in docs/cli-setup.md docs/killercoda-setup.md docs/killercoda-user.md docs/codespaces-setup.md docs/kind-setup.md docs/hard-setup.md docs/quickstart-tiers.md docs/user-guide.md docs/lab-guide.md; do
    [ -f "$f" ] && ok "$f" || bad "$f missing"; done
  for s in scripts/5-spot-bootstrap.sh scripts/setup-mac.sh; do
    [ -x "$s" ] && bash -n "$s" && ok "$s (exec + syntax)" || bad "$s"; done
  # version-pin consistency between bootstrap and pre-bakes
  local pins
  pins=$(grep -h 'CLUSTERCTL_VERSION=' scripts/5-spot-bootstrap.sh killercoda/*/setup-background.sh .devcontainer/post-create.sh \
        | sed -E 's/.*CLUSTERCTL_VERSION="?([^" #]+)"?.*/\1/' | sort -u | wc -l)
  [ "$pins" -eq 1 ] && ok "clusterctl pin consistent everywhere (incl. devcontainer)" || bad "clusterctl pin DRIFT across scripts"
  pins=$(grep -h 'FIVESPOT_IMAGE=' killercoda/*/setup-background.sh \
        | sed -E 's/.*FIVESPOT_IMAGE="?([^" #]+)"?.*/\1/' | sort -u | wc -l)
  [ "$pins" -le 1 ] && ok "5-spot image pin consistent" || bad "5-spot image pin drift"
}

static_killercoda() {
  section "Killercoda (static)"
  for sc in killercoda/5spot-ctf-capd killercoda/5spot-ctf-k0smotron; do
    python3 -c "import json;json.load(open('$sc/index.json'))" 2>/dev/null && ok "$sc/index.json valid" || bad "$sc/index.json"
    # every step file referenced in index.json must exist
    python3 - "$sc" <<'PYEOF' && ok "$sc step files all present" || bad "$sc missing step files"
import json,sys,os
sc=sys.argv[1]; d=json.load(open(f"{sc}/index.json"))["details"]
files=[d["intro"]["text"], d["intro"].get("background",""), d["finish"]["text"]]
for s in d["steps"]: files += [s["text"], s.get("verify","")]
missing=[f for f in files if f and not os.path.exists(f"{sc}/{f}")]
sys.exit(1 if missing else 0)
PYEOF
    for sh in "$sc"/setup-background.sh "$sc"/*/verify.sh; do
      bash -n "$sh" 2>/dev/null && : || bad "syntax: $sh"; done
    ok "$sc shell syntax"
    for y in "$sc"/assets/*.yaml "$sc"/assets/flux/*.yaml; do
      python3 -c "import yaml,sys;list(yaml.safe_load_all(open('$y')))" 2>/dev/null && : || bad "yaml: $y"; done
    ok "$sc yaml parses"
  done
  # the k0smotron flux overlay must be the k0smotron SM, not CAPD
  grep -q "RemoteMachine" killercoda/5spot-ctf-k0smotron/assets/flux/scheduledmachine.yaml \
    && ok "k0smotron flux overlay uses RemoteMachine" || bad "k0smotron flux overlay is NOT the k0smotron SM"
  # no stale paths
  grep -rq "5spot-ctf/assets" killercoda/ && bad "stale '5spot-ctf/assets' path found" || ok "no stale scenario paths"
  # portability: no hardcoded /root (breaks non-root Medium/Hard users)
  grep -rqE '(^|[^$])/root/' killercoda/*/setup-background.sh killercoda/*/*/verify.sh killercoda/*/step*/text.md 2>/dev/null \
    && bad "hardcoded /root path found (use \$HOME)" || ok "no hardcoded /root paths"
  # helm present in pre-bakes (Flux/CoCo bonuses need it)
  for s in killercoda/*/setup-background.sh; do
    grep -q "get-helm-3" "$s" && ok "helm installed by $(dirname "$s" | xargs basename)" || bad "helm missing from $s"; done
}

static_leaderboard() {
  section "Leaderboard (static)"
  python3 -c "import yaml;yaml.safe_load(open('leaderboard/docker-compose.yml'))" 2>/dev/null \
    && ok "leaderboard/docker-compose.yml valid" || bad "leaderboard compose"
  python3 -m py_compile leaderboard/seed-ctfd.py 2>/dev/null && ok "seed-ctfd.py compiles" || bad "seed-ctfd.py"
  python3 -m py_compile leaderboard/flagboard.py 2>/dev/null && ok "flagboard.py compiles" || bad "flagboard.py"
  n=$(grep -l 'post_flag()' killercoda/*/*/verify.sh | wc -l)
  total=$(ls killercoda/*/*/verify.sh | wc -l)
  [ "$n" -eq "$total" ] && ok "auto-post hook in all $total verifiers" || bad "post_flag hook missing ($n/$total)"
  [ -x scripts/make-qr.sh ] && bash -n scripts/make-qr.sh && ok "make-qr.sh" || bad "make-qr.sh"
  n=$(grep -rhoE 'FLAG\{[A-Z0-9_]+\}' killercoda/*/*/verify.sh | sort -u | wc -l)
  [ "$n" -ge 5 ] && ok "flag inventory: $n unique flags for the seeder" || bad "flag inventory looks wrong ($n)"
}

static_codespaces() {
  section "Codespaces (static)"
  python3 -c "import json,re;t=open('.devcontainer/devcontainer.json').read();t=re.sub(r'//.*','',t);json.loads(t)" 2>/dev/null \
    && ok ".devcontainer/devcontainer.json valid" || bad ".devcontainer/devcontainer.json"
  [ -x .devcontainer/post-create.sh ] && bash -n .devcontainer/post-create.sh && ok "post-create.sh" || bad "post-create.sh"
}

static_kind() {
  section "kind / local (static)"
  bash -n killercoda/5spot-ctf-capd/setup-background.sh && ok "CAPD bring-up script syntax" || bad "CAPD script"
  ./scripts/5-spot-bootstrap.sh --env-tier kind --check-only >/dev/null 2>&1
  case $? in 0) ok "bootstrap --check-only: kind tier complete on THIS host";;
    1) ok "bootstrap --check-only ran (some tools missing on this host — expected off-workshop)";;
    *) bad "bootstrap --check-only crashed";; esac
}

# ---------- live checks --------------------------------------------------------
live_kind() {
  section "kind / CAPD (LIVE — this boots clusters, several minutes)"
  command -v docker >/dev/null && docker info >/dev/null 2>&1 || { bad "docker unavailable — skipping live"; return; }
  local t0=$SECONDS
  if bash killercoda/5spot-ctf-capd/setup-background.sh; then
    ok "pre-bake completed in $((SECONDS-t0))s"
    # Flag 1 end-to-end: apply SM, wait for node Ready, run the real verifier
    kubectl --context kind-5spot-mgmt apply -f killercoda/5spot-ctf-capd/assets/scheduledmachine-business-hours.yaml \
      && ok "ScheduledMachine applied" || bad "SM apply failed"
    local deadline=$((SECONDS+600))
    until bash killercoda/5spot-ctf-capd/step1-deploy/verify.sh >/dev/null 2>&1; do
      [ $SECONDS -gt $deadline ] && break; sleep 15; done
    bash killercoda/5spot-ctf-capd/step1-deploy/verify.sh && ok "FLAG 1 verifier passes live" || bad "Flag 1 never verified (timeout)"
    # Flag 2
    kubectl --kubeconfig "$HOME/dev-cluster.kubeconfig" apply -f killercoda/5spot-ctf-capd/assets/spot-workload.yaml \
      || kubectl --kubeconfig "$HOME/dev-cluster.kubeconfig" apply -f killercoda/5spot-ctf-capd/assets/spot-workload.yaml 2>/dev/null
    sleep 30; bash killercoda/5spot-ctf-capd/step2-taint/verify.sh && ok "FLAG 2 verifier passes" || bad "Flag 2 failed"
    # Flag 3
    kubectl --context kind-5spot-mgmt patch sm business-hours-worker --type merge -p '{"spec":{"schedule":{"enabled":false}}}' >/dev/null 2>&1
    deadline=$((SECONDS+600))
    until bash killercoda/5spot-ctf-capd/step3-drain/verify.sh >/dev/null 2>&1; do
      [ $SECONDS -gt $deadline ] && break; sleep 15; done
    bash killercoda/5spot-ctf-capd/step3-drain/verify.sh && ok "FLAG 3 verifier passes (graceful drain)" || bad "Flag 3 failed"
  else
    bad "CAPD pre-bake failed — read the log above"
  fi
  $KEEP || { kind delete cluster --name 5spot-mgmt >/dev/null 2>&1; ok "torn down (use --keep to retain)"; }
}

live_k0smotron() {
  section "k0smotron (LIVE — heaviest; needs an SSH-able target via REMOTE_NODE_HOST)"
  command -v docker >/dev/null && docker info >/dev/null 2>&1 || { bad "docker unavailable — skipping"; return; }
  [ -n "${REMOTE_NODE_HOST:-}" ] || { bad "set REMOTE_NODE_HOST=<ssh-able host/IP> to live-test this tier"; return; }
  if REMOTE_NODE_HOST="$REMOTE_NODE_HOST" bash killercoda/5spot-ctf-k0smotron/setup-background.sh; then
    ok "k0smotron pre-bake completed"
    kubectl --context kind-5spot-mgmt apply -f "$HOME/5spot-workshop/scheduledmachine-k0smotron.yaml" 2>/dev/null \
      || kubectl --context kind-5spot-mgmt apply -f killercoda/5spot-ctf-k0smotron/assets/scheduledmachine-k0smotron.yaml
    local deadline=$((SECONDS+900))
    until bash killercoda/5spot-ctf-k0smotron/step1-deploy/verify.sh >/dev/null 2>&1; do
      [ $SECONDS -gt $deadline ] && break; sleep 20; done
    bash killercoda/5spot-ctf-k0smotron/step1-deploy/verify.sh && ok "FLAG 1 (remote worker) live" || bad "remote worker never Ready — check RemoteMachine fields vs your k0smotron release"
  else
    bad "k0smotron pre-bake failed"
  fi
  $KEEP || { kind delete cluster --name 5spot-mgmt >/dev/null 2>&1; ok "torn down"; }
}

# ---------- run ----------------------------------------------------------------
case "$TIER" in
  all)        static_repo; static_killercoda; static_codespaces; static_leaderboard; static_kind
              $LIVE && { live_kind; };;
  killercoda) static_killercoda;;
  codespaces) static_codespaces;;
  kind)       static_kind; $LIVE && live_kind;;
  k0smotron)  static_killercoda; $LIVE && live_k0smotron;;
  *) echo "unknown tier '$TIER'"; exit 2;;
esac

printf '\n━━ RESULT: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m ━━\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
