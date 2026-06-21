#!/usr/bin/env bash
# =============================================================================
# iximiuz-publish.sh — ensure the labctl CLI exists, then publish the 5-Spot
# content (skill path + two challenges) to iximiuz Labs.
#
#   ./scripts/iximiuz-publish.sh            # ensure labctl, auth, create+push all
#   ./scripts/iximiuz-publish.sh --install  # only ensure labctl is installed
#
# Idempotent: `content create` registers an item server-side (tolerated if it
# already exists); `content push --force` uploads our authored source. The
# create step scaffolds into a throwaway temp dir so it can never overwrite the
# files under iximiuz/. Docs: docs/iximiuz-setup.md
# =============================================================================
set -uo pipefail
cd "$(dirname "$0")/.."   # repo root

LABCTL_BIN_DIR="$HOME/.iximiuz/labctl/bin"

# ---- 1) ensure labctl is installed -----------------------------------------
ensure_labctl() {
  if command -v labctl >/dev/null 2>&1; then
    echo "✓ labctl present: $(command -v labctl)"
  elif [ -x "$LABCTL_BIN_DIR/labctl" ]; then
    echo "✓ labctl present: $LABCTL_BIN_DIR/labctl (adding to PATH for this run)"
    export PATH="$LABCTL_BIN_DIR:$PATH"
  else
    echo "→ labctl not found — installing the iximiuz Labs CLI…"
    curl -sf https://labs.iximiuz.com/cli/install.sh | sh || {
      echo "✗ labctl install failed. Manual: https://github.com/iximiuz/labctl (or 'brew install labctl')"; exit 1; }
    export PATH="$LABCTL_BIN_DIR:$PATH"
    command -v labctl >/dev/null 2>&1 || [ -x "$LABCTL_BIN_DIR/labctl" ] || {
      echo "✗ labctl still not on PATH after install — open a new shell or add $LABCTL_BIN_DIR to PATH"; exit 1; }
    echo "✓ labctl installed → $LABCTL_BIN_DIR (add it to your PATH permanently in your shell rc)"
  fi
}

ensure_labctl
[ "${1:-}" = "--install" ] && exit 0

# ---- 2) ensure authenticated -----------------------------------------------
# Note: `labctl auth whoami` exits 0 even when logged out (it prints "Not logged
# in" to stdout), so gate on the message, not the exit code.
WHOAMI="$(labctl auth whoami 2>&1)"
if printf '%s' "$WHOAMI" | grep -qi 'not logged in'; then
  echo "✗ Not authenticated. Run:  labctl auth login"
  echo "  (then re-run: make iximiuz-publish)"
  exit 1
fi
echo "✓ authenticated: $(printf '%s' "$WHOAMI" | head -1)"

# ---- 3) publish each item (create once, then push our source) --------------
# "kind name dir" — dir is <kind>s/<name> under iximiuz/. CHALLENGES FIRST: the
# skill-path's units reference the challenges, so they must exist before it.
ITEMS=(
  "challenge  5spot-ctf-capd      challenges/5spot-ctf-capd"
  "challenge  5spot-ctf-k0smotron challenges/5spot-ctf-k0smotron"
  "skill-path 5-spot-ctf          skill-paths/5-spot-ctf"
  "training   5-spot-workshop     trainings/5-spot-workshop"
)

# `labctl content create` is INTERACTIVE — it asks a y/N confirmation on the
# terminal (there is no --yes flag; --quiet still prompts). So this script must be
# run from a real terminal, and you'll be asked to confirm each new item. Don't
# suppress create's output or it'll appear to hang on an invisible prompt.
if [ ! -t 0 ]; then
  echo "⚠ No interactive terminal detected. 'labctl content create' needs a TTY to"
  echo "  confirm each new item — run this from a normal terminal (not piped/CI)."
fi
echo "→ You'll be asked 'y/N' to confirm each NEW item below. Answer y."
echo

# `labctl content create` registers the item under a SERVER-GENERATED slug — it
# appends a random suffix, e.g. `5spot-ctf-capd` → `5spot-ctf-capd-f3d76f57`. So we
# can't push by our base name (that 404s), and re-creating spawns duplicates.
# Resolve the real slug from `content list` (base name + optional -<hex> suffix);
# only create when none exists, then push to the resolved slug.
resolve_slug() { # basename  →  prints the real slug, or empty
  labctl content list 2>/dev/null \
    | sed -n 's/^[[:space:]]*name:[[:space:]]*//p' \
    | grep -E "^$1(-[a-f0-9]+)?$" | head -1
}

cd iximiuz
fail=0
URLS=()
for item in "${ITEMS[@]}"; do
  # shellcheck disable=SC2086
  set -- $item
  kind="$1" name="$2" dir="$3"
  [ -f "$dir/index.md" ] || { echo "✗ missing $dir/index.md — run from repo root"; fail=1; continue; }

  echo "── $kind/$name ──"
  slug="$(resolve_slug "$name")"
  if [ -n "$slug" ]; then
    echo "  • reusing existing slug: $slug"
  else
    # New item. Create against a COPY in a throwaway dir so it can never touch our
    # real source. Prompt is shown (interactive). Then re-resolve to learn the slug
    # the server assigned — we deliberately don't parse create's stdout (it prompts).
    tmp="$(mktemp -d)"; cp -R "$dir/." "$tmp/" 2>/dev/null || true
    labctl content create "$kind" "$name" --dir "$tmp" --no-open || true
    rm -rf "$tmp"
    slug="$(resolve_slug "$name")"
    [ -n "$slug" ] && echo "  • created slug: $slug" || { echo "  ✗ could not resolve slug for $kind/$name after create"; fail=1; continue; }
  fi

  # Upload our authored source to the resolved slug (--force makes remote match
  # local exactly and is non-interactive).
  if labctl content push "$kind" "$slug" --dir "$dir" --force; then
    echo "  ✓ pushed $dir → $slug"
    URLS+=("https://labs.iximiuz.com/${kind}s/$slug")   # kind→path: challenge→challenges, skill-path→skill-paths
  else
    echo "  ✗ push failed for $kind/$slug"; fail=1
  fi
done

echo
if [ "$fail" = 0 ]; then
  echo "✓ Published. Live URLs (the server assigns a -<hex> slug; these are the real ones):"
  for u in "${URLS[@]}"; do echo "    $u"; done
  echo
  echo "⚠ New content is visible only to YOU (the author) by default. To let attendees"
  echo "  open these, set each item's visibility to public/listed in the iximiuz UI."
else
  echo "✗ One or more items failed — see output above."
fi
exit $fail
