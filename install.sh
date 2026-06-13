#!/bin/bash
# Fast setup — VPS kosong → Windows Ghost Spectre golden (zero manual setup)
# Usage: curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/install.sh | bash

set -euo pipefail

GOLDEN_URL="${GOLDEN_URL:-https://archive.org/download/windows-golden.tar/windows-golden.tar.gz}"
GOLDEN_MIN_BYTES="${GOLDEN_MIN_BYTES:-5000000000}"  # ~5 GB, archive ~5.5 GB
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

golden_is_valid() {
  local out="golden/windows-golden.tar.gz"
  [[ -f "$out" ]] || return 1
  local size
  size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
  if (( size < GOLDEN_MIN_BYTES )); then
    echo "  Golden corrupt/tidak lengkap ($(numfmt --to=iec "$size" 2>/dev/null || echo "${size} bytes"), butuh ~5.5G)"
    return 1
  fi
  if ! gzip -t "$out" 2>/dev/null; then
    echo "  Golden corrupt (gzip check gagal)"
    return 1
  fi
  return 0
}

download_golden() {
  local out="golden/windows-golden.tar.gz"

  if golden_is_valid; then
    echo "  Golden sudah ada & valid, skip download."
    return 0
  fi

  if [[ -f "$out" ]]; then
    echo "  Hapus file golden rusak/tidak lengkap..."
    rm -f "$out"
  fi

  # aria2 multi-connection jauh lebih cepat dari archive.org vs wget single-thread
  if ! command -v aria2c &>/dev/null; then
    echo "  Install aria2 (download paralel)..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq aria2
  fi

  if command -v aria2c &>/dev/null; then
    echo "  Download via aria2 (16 koneksi, resume OK)..."
    aria2c -x 16 -s 16 -k 1M -c --file-allocation=none \
      -d golden -o windows-golden.tar.gz "$GOLDEN_URL"
  else
    echo "  Download via wget (fallback)..."
    wget -c -O "$out" "$GOLDEN_URL"
  fi

  golden_is_valid || { echo "ERROR: Download golden gagal atau masih corrupt."; exit 1; }
}

echo "[5/7] Download golden image (~5.5 GB)..."
echo "  Tip: upload ke host cepat lalu GOLDEN_URL=... bash install.sh"
mkdir -p golden
download_golden

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
