#!/bin/bash
# Fast setup — VPS kosong → Windows Ghost Spectre golden (zero manual setup)
# Usage: curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/install.sh | bash

set -euo pipefail

GOLDEN_URL="${GOLDEN_URL:-https://archive.org/download/windows-golden.tar/windows-golden.tar.gz}"
REPO="${REPO:-https://github.com/Kurniaharun/docker-windows.git}"
INSTALL_DIR="${INSTALL_DIR:-/root/docker-windows}"
COMPOSE="compose.ghostspectre.yml"

[[ $EUID -eq 0 ]] || { echo "ERROR: Jalankan sebagai root (sudo bash)"; exit 1; }

echo "=========================================="
echo " Ghost Spectre Golden — Fast Setup"
echo "=========================================="

echo "[1/7] Cek KVM..."
if [[ ! -e /dev/kvm ]]; then
  echo "ERROR: /dev/kvm tidak ada. VPS tidak support nested virtualization."
  exit 1
fi
echo "  KVM OK"

echo "[2/7] Install Docker..."
if ! command -v docker &>/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  curl -fsSL https://get.docker.com | sh
fi
docker --version

echo "[3/7] Clone / update repo..."
if [[ -d "$INSTALL_DIR/.git" ]]; then
  git -C "$INSTALL_DIR" pull origin master
else
  rm -rf "$INSTALL_DIR"
  git clone "$REPO" "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"
chmod +x scripts/*.sh 2>/dev/null || true

echo "[4/7] Build Docker image..."
docker build -t dockurr/windows:ghostspectre .

echo "[5/7] Download golden image (~5.5 GB)..."
mkdir -p golden
if [[ ! -f golden/windows-golden.tar.gz ]]; then
  wget -c -O golden/windows-golden.tar.gz "$GOLDEN_URL"
else
  echo "  Golden sudah ada, skip download."
fi

echo "[6/7] Restore golden image..."
docker compose -f "$COMPOSE" down 2>/dev/null || true
docker rm -f windows 2>/dev/null || true
rm -rf windows
mkdir -p windows shared
tar -xzf golden/windows-golden.tar.gz -C "$INSTALL_DIR"

echo "[7/7] Start Windows..."
docker compose -f "$COMPOSE" up -d

sleep 8
IP=$(hostname -I | awk '{print $1}')

echo ""
echo "=========================================="
echo " SELESAI — Windows siap pakai!"
echo "=========================================="
echo "  Web viewer : http://${IP}:8006"
echo "  RDP tunnel : ssh -N -L 13389:127.0.0.1:8007 root@${IP}"
echo "  RDP connect: localhost:13389"
echo "  User       : Administrator"
echo "  Password   : 12345678"
echo "=========================================="
docker compose -f "$COMPOSE" ps
