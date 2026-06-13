#!/bin/bash
# Backup Windows golden image (data.img + metadata)
# Usage: ./scripts/backup-golden.sh [output-name]

set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
STORAGE="${DIR}/windows"
OUTPUT="${DIR}/golden"
NAME="${1:-windows-golden}"
ARCHIVE="${OUTPUT}/${NAME}.tar.gz"

if [ ! -f "${STORAGE}/data.img" ]; then
  echo "ERROR: ${STORAGE}/data.img tidak ditemukan."
  echo "Install Windows dulu sebelum backup."
  exit 1
fi

echo "=== Stop container ==="
cd "$DIR"
docker compose -f compose.ghostspectre.yml down 2>/dev/null || \
docker compose down 2>/dev/null || true

echo "=== Backup golden image ==="
mkdir -p "$OUTPUT"

# Hanya file penting — skip ISO (besar & tidak perlu)
tar -czf "$ARCHIVE" \
  -C "$DIR" \
  --exclude='windows/*.iso' \
  windows/

SIZE=$(du -h "$ARCHIVE" | cut -f1)
echo ""
echo "Selesai!"
echo "  File : $ARCHIVE"
echo "  Size : $SIZE"
echo ""
echo "Restore: ./scripts/restore-golden.sh $NAME"
