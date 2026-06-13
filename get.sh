#!/bin/bash
# Bootstrap — clone repo (hindari CDN cache raw.githubusercontent.com)
# Usage: curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/get.sh | bash

set -euo pipefail

REPO="${REPO:-https://github.com/Kurniaharun/docker-windows.git}"
INSTALL_DIR="${INSTALL_DIR:-/root/docker-windows}"

echo ">>> Clone repo dari GitHub (selalu versi terbaru)..."
rm -rf "$INSTALL_DIR"
git clone --depth 1 "$REPO" "$INSTALL_DIR"

echo ">>> Jalankan install.sh..."
exec bash "$INSTALL_DIR/install.sh"
