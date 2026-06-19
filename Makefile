# 5-Spot Workshop — facilitator scaffolding.
# Run `make help` for the menu. User-facing setup lives in scripts/ and docs/.

SHELL := /bin/bash
REPO_URL ?= https://github.com/YOUR-ORG/5-spot-workshop

.PHONY: help validate codespaces killercoda kind hard kind-down hard-down codespaces-down killercoda-down teardown test test-live-kind test-live-k0smotron slides clean

help: ## Show this menu
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "};{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

validate: ## Static-validate everything (JSON/YAML/bash, structure, pins)
	./scripts/test-tiers.sh

codespaces: ## Scaffold/verify the Codespaces tier (.devcontainer) and print go-live steps
	@test -f .devcontainer/devcontainer.json && echo "✓ .devcontainer present" || (echo "✗ .devcontainer missing"; exit 1)
	@python3 -c "import json,re;t=open('.devcontainer/devcontainer.json').read();json.loads(re.sub(r'//.*','',t));print('✓ devcontainer.json valid')"
	@bash -n .devcontainer/post-create.sh && echo "✓ post-create.sh syntax"
	@echo ""
	@echo "Go live:  1) push this repo (public)   2) repo → Code ▸ Codespaces ▸ Create"
	@echo "          3) pick an 8-core/16GB machine type   4) users: scripts/5-spot-bootstrap.sh --env-tier codespaces"

killercoda: ## Validate both Killercoda scenarios and print wiring steps
	./scripts/test-tiers.sh --tier killercoda
	@echo ""
	@echo "Go live:  1) push this repo (public)   2) killercoda.com → sign in with GitHub"
	@echo "          3) Creators → connect repo → add scenarios at:"
	@echo "             killercoda/5spot-ctf-capd    and    killercoda/5spot-ctf-k0smotron"
	@echo "          4) every git push auto-updates. Full guide: docs/killercoda-setup.md"

kind: ## Bring up the CAPD environment locally (facilitator rehearsal)
	./scripts/5-spot-bootstrap.sh --env-tier kind
	bash killercoda/5spot-ctf-capd/setup-background.sh

kind-down: ## FULL teardown of the kind/CAPD tier (mgmt cluster + leaked workload containers)
	./scripts/5-spot-teardown.sh --env-tier kind $(TEARDOWN_ARGS)

hard-down: ## FULL teardown of the hard/k0smotron tier (mgmt + hosted CP + remote k0s worker)
	./scripts/5-spot-teardown.sh --env-tier hard $(TEARDOWN_ARGS)

codespaces-down: ## FULL teardown inside a Codespace (same as kind/CAPD)
	./scripts/5-spot-teardown.sh --env-tier codespaces $(TEARDOWN_ARGS)

killercoda-down: ## Teardown note for Killercoda (the browser VM is discarded automatically)
	./scripts/5-spot-teardown.sh --env-tier killercoda

teardown: ## Tear down a tier: make teardown TIER=kind|hard|codespaces|killercoda [TEARDOWN_ARGS=--purge]
	@test -n "$(TIER)" || (echo "pass TIER=kind|hard|codespaces|killercoda"; exit 1)
	./scripts/5-spot-teardown.sh --env-tier $(TIER) $(TEARDOWN_ARGS)

test: ## Static test of every tier (safe anywhere)
	./scripts/test-tiers.sh

test-live-kind: ## FULL live test of the CAPD tier — boots clusters, runs all 3 flag verifiers
	./scripts/test-tiers.sh --tier kind --live

test-live-k0smotron: ## FULL live test of the k0smotron tier (set REMOTE_NODE_HOST=<ssh host>)
	./scripts/test-tiers.sh --tier k0smotron --live

leaderboard-up: ## Start the CTFd leaderboard (http://localhost:8000 — finish the setup wizard)
	cd leaderboard && docker compose up -d
	@echo "→ open http://localhost:8000, complete setup, create an Access Token, then: make leaderboard-seed CTFD_TOKEN=..."

leaderboard-seed: ## Create the 5 challenges from the repo's flags (CTFD_TOKEN=... [CTFD_URL=...])
	CTFD_URL=$${CTFD_URL:-http://localhost:8000} CTFD_TOKEN=$(CTFD_TOKEN) python3 leaderboard/seed-ctfd.py

flagboard: ## Start the zero-dependency live wallboard + flag API (http://localhost:5050)
	python3 leaderboard/flagboard.py

leaderboard-tunnel: ## Free public URL via Cloudflare quick tunnel (PORT=5050 for flagboard, default 8000 for CTFd)
	@command -v cloudflared >/dev/null || (echo "install cloudflared: brew install cloudflared | apt install cloudflared"; exit 1)
	cloudflared tunnel --url http://localhost:$${PORT:-8000}

leaderboard-down: ## Stop the leaderboard (data persists in the docker volume)
	cd leaderboard && docker compose down

qr: ## Generate a QR PNG (make qr URL=https://... OUT=slides/qr-leaderboard.png)
	./scripts/make-qr.sh $(URL) $${OUT:-qr.png}

salt-flags: ## Append a per-event salt to every FLAG{...} so public-repo flags aren't usable day-of (make salt-flags SALT=OSFF26)
	@test -n "$(SALT)" || (echo "pass SALT=<short-string>"; exit 1)
	@grep -rl 'FLAG{' killercoda/*/*/verify.sh | xargs sed -i.bak -E 's/FLAG\{([A-Z0-9_]+)\}/FLAG{\1_$(SALT)}/g'
	@find killercoda -name "*.bak" -delete
	@echo "✓ flags salted with _$(SALT). Re-seed the leaderboard: make leaderboard-seed CTFD_TOKEN=..."
	@echo "  (commit this only to a PRIVATE branch, or salt just before the event)"

set-repo: ## Replace YOUR-ORG placeholder with REPO_URL everywhere (make set-repo REPO_URL=https://github.com/me/5-spot-workshop)
	@test "$(REPO_URL)" != "https://github.com/YOUR-ORG/5-spot-workshop" || (echo "pass REPO_URL=<your real repo url>"; exit 1)
	@grep -rl "YOUR-ORG/5-spot-workshop" --include="*.md" . | xargs -r sed -i.bak "s|https://github.com/YOUR-ORG/5-spot-workshop|$(REPO_URL)|g"
	@find . -name "*.bak" -delete
	@echo "✓ placeholders replaced with $(REPO_URL) (slides: edit the closing slide manually)"

slides: ## Where the deck lives
	@ls -la slides/ 2>/dev/null || echo "slides/5-spot-workshop.pptx (regenerate: see slides/README)"

clean: ## FULL teardown + purge of local state (kind/CAPD and hard/k0smotron, removes clones/keys)
	./scripts/5-spot-teardown.sh --env-tier hard --purge
	@echo "clean."
