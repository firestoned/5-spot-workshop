#!/usr/bin/env bash
# Generate a QR code PNG for any URL (leaderboard, repo, docs).
#   ./scripts/make-qr.sh https://your-leaderboard.example slides/qr-leaderboard.png
set -euo pipefail
URL="${1:?usage: make-qr.sh <url> [outfile.png]}"
OUT="${2:-qr.png}"
python3 -c "import qrcode" 2>/dev/null || pip install "qrcode[pil]" --break-system-packages -q
python3 - "$URL" "$OUT" <<'PYEOF'
import sys, qrcode
img = qrcode.make(sys.argv[1], box_size=12, border=2)
img.save(sys.argv[2])
print(f"✓ {sys.argv[2]}  →  {sys.argv[1]}")
PYEOF
