#!/usr/bin/env bash
# Install the canonical kubectl aliases (workshop/shared/kubectl-aliases.sh) so
# every interactive shell on this machine picks them up. Idempotent, with a
# sudo fallback. Called by each tier's pre-bake; also safe to run standalone:
#
#     bash workshop/shared/install-aliases.sh
#
# Single source of truth: the alias LIST lives only in kubectl-aliases.sh; this
# script only wires it into the shell startup files.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/kubectl-aliases.sh"
[ -f "$SRC" ] || { echo "  (kubectl-aliases.sh not found next to install-aliases.sh — skipping aliases)"; exit 0; }

# Copy the aliases to a stable, world-readable path so the shell rc files can
# source it regardless of where the repo lives (and even if the clone is removed).
DST=/etc/profile.d/5spot-aliases.sh
if cp "$SRC" "$DST" 2>/dev/null || sudo cp "$SRC" "$DST" 2>/dev/null; then
  SOURCE_PATH="$DST"
else
  SOURCE_PATH="$SRC"   # fall back to sourcing straight from the repo
fi

MARKER='5-spot kubectl aliases'
LINE="[ -f '$SOURCE_PATH' ] && . '$SOURCE_PATH'  # $MARKER"

append() { # $1 = rc file — add the source line once (marker-guarded), sudo if needed
  grep -q "$MARKER" "$1" 2>/dev/null && return 0
  if { [ -e "$1" ] && [ -w "$1" ]; } || { [ ! -e "$1" ] && [ -w "$(dirname "$1")" ]; }; then
    printf '\n%s\n' "$LINE" >> "$1"
  else
    printf '\n%s\n' "$LINE" | sudo tee -a "$1" >/dev/null 2>&1 || return 0
  fi
}

# Interactive non-login shells (Codespaces, iximiuz playgrounds) read
# /etc/bash.bashrc + ~/.bashrc; zsh users read ~/.zshrc; login shells also
# auto-source /etc/profile.d/*.sh. Cover them all (double-sourcing is harmless).
append /etc/bash.bashrc
append "${HOME:-/root}/.bashrc"
[ -n "${HOME:-}" ] && append "$HOME/.zshrc"

echo "==> kubectl aliases installed (k, kgp, ksm, kmgmt, kwl, …)"
echo "    Load them in your CURRENT shell now:  exec bash   (or open a new terminal)"
