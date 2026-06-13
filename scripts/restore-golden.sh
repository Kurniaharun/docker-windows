#!/bin/bash
# Restore Windows golden image — boot langsung tanpa install ulang
# Usage: ./scripts/restore-golden.sh [archive-name]

set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="${DIR}/golden"
NAME="${1:-windows-golden}"
ARCHIVE="${OUTPUT}/${NAME}.tar.gz"
COMPOSE="${2:-compose.ghostspectre.yml}"

if [ ! -f "$ARCHIVE" ]; then
  echo "ERROR: Archive tidak ditemukan: $ARCHIVE"
  echo "Upload dulu golden image ke folder golden/"
  exit 1
fi

echo "=== Stop container lama ==="
cd "$DIR"
docker compose -f "$COMPOSE" down 2>/dev/null || true
docker rm -f windows 2>/dev/null || true

echo "=== Restore data.img ==="
rm -rf "${DIR}/windows"
mkdir -p "${DIR}/windows"
tar -xzf "$ARCHIVE" -C "$DIR"

echo "=== Start Windows (langsung boot, no install) ==="
docker compose -f "$COMPOSE" up -d

sleep 5
docker compose -f "$COMPOSE" ps

echo ""
echo "Selesai! Windows langsung boot dari golden image."
echo "  Web : http://$(hostname -I | awk '{print $1}'):8006"
echo "  RDP : port 8007 (pakai SSH tunnel)"
