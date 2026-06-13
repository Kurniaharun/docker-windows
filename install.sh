#!/bin/bash
# Fast setup — VPS kosong → Windows Ghost Spectre golden (zero manual setup)
# Usage: curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/install.sh | bash

set -euo pipefail

GOLDEN_URL="${GOLDEN_URL:-https://archive.org/download/windows-golden.tar/windows-golden.tar.gz}"
GOLDEN_MIN_BYTES="${GOLDEN_MIN_BYTES:-5000000000}"   # ~5 GB, archive ~5.5 GB
GOLDEN_FILE="windows-golden.tar.gz"
DATA_IMG_MIN_BYTES="${DATA_IMG_MIN_BYTES:-8000000000}"  # data.img minimal ~8 GB
DISK_MIN_FREE_KB="${DISK_MIN_FREE_KB:-25000000}"       # ~25 GB kosong untuk download+extract
REPO="${REPO:-https://github.com/Kurniaharun/docker-windows.git}"
INSTALL_DIR="${INSTALL_DIR:-/root/docker-windows}"
COMPOSE="compose.ghostspectre.yml"
IMAGE="dockurr/windows:ghostspectre"
CONTAINER="windows"
LOG_FILE="${LOG_FILE:-/var/log/ghostspectre-install.log}"
STEP=0
TOTAL_STEPS=7
START_TS=$(date +%s)

# ── Logging ──────────────────────────────────────────────────────────────────

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="${INSTALL_DIR}/install.log"

_ts() { date '+%Y-%m-%d %H:%M:%S'; }

_log() {
  local level="$1" msg="$2"
  local line="[$(_ts)] [$level] $msg"
  echo "$line" | tee -a "$LOG_FILE"
}

log_info()  { _log "INFO"  "$*"; }
log_ok()    { _log " OK "  "$*"; }
log_warn()  { _log "WARN"  "$*"; }
log_err()   { _log "ERROR" "$*"; }

step() {
  STEP=$((STEP + 1))
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log_info "[$STEP/$TOTAL_STEPS] $*"
  log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

fmt_bytes() {
  local b="$1"
  if command -v numfmt &>/dev/null; then
    numfmt --to=iec-i --suffix=B "$b" 2>/dev/null || echo "${b}B"
  else
    echo "${b} bytes"
  fi
}

fmt_kb() {
  local kb="$1"
  if command -v numfmt &>/dev/null; then
    numfmt --from-unit=1024 --to=iec "$kb" 2>/dev/null || echo "${kb}KB"
  else
    echo "$(( kb / 1024 / 1024 ))GB"
  fi
}

elapsed() {
  local now=$(( $(date +%s) - START_TS ))
  printf '%dm%02ds' $((now / 60)) $((now % 60))
}

on_error() {
  local line="$1"
  log_err "Script gagal di baris $line (elapsed: $(elapsed))"
  log_err "Log lengkap: $LOG_FILE"
  log_info "Auto-fix tips:"
  log_info "  - Golden rusak  → rm -f $INSTALL_DIR/golden/$GOLDEN_FILE lalu jalankan ulang"
  log_info "  - Disk penuh    → df -h /  (butuh ~25GB kosong)"
  log_info "  - KVM tidak ada → ganti VPS yang support nested virtualization"
  exit 1
}
trap 'on_error $LINENO' ERR

# ── Auto-fix helpers ─────────────────────────────────────────────────────────

auto_fix_disk() {
  local avail_kb
  avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
  log_info "Disk tersedia: $(fmt_kb "$avail_kb") (minimal: $(fmt_kb "$DISK_MIN_FREE_KB"))"
  if (( avail_kb < DISK_MIN_FREE_KB )); then
    log_warn "Auto-fix: disk hampir penuh, bersihkan cache Docker..."
    docker system prune -af --volumes 2>/dev/null || true
    apt-get clean 2>/dev/null || true
    avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
    log_info "Disk setelah cleanup: $(fmt_kb "$avail_kb")"
    if (( avail_kb < DISK_MIN_FREE_KB )); then
      log_err "Disk tidak cukup. Butuh ~25GB kosong. Saat ini: $(fmt_kb "$avail_kb")"
      exit 1
    fi
    log_ok "Auto-fix disk: cleanup berhasil"
  else
    log_ok "Disk OK"
  fi
}

auto_fix_container() {
  log_info "Auto-fix: stop container lama jika ada..."
  docker compose -f "$INSTALL_DIR/$COMPOSE" down 2>/dev/null || true
  docker rm -f "$CONTAINER" 2>/dev/null || true
  log_ok "Container lama dibersihkan"
}

auto_fix_aria2() {
  if command -v aria2c &>/dev/null; then
    log_ok "aria2 sudah terinstall: $(aria2c --version | head -1)"
    return 0
  fi
  log_warn "Auto-fix: install aria2 untuk download paralel..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq aria2
  log_ok "aria2 terinstall"
}

golden_is_valid() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  [[ -f "$out" ]] || return 1
  local size
  size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
  if (( size < GOLDEN_MIN_BYTES )); then
    log_warn "Golden tidak lengkap: $(fmt_bytes "$size") / minimal $(fmt_bytes "$GOLDEN_MIN_BYTES")"
    return 1
  fi
  if ! gzip -t "$out" 2>/dev/null; then
    log_warn "Golden corrupt (gzip check gagal)"
    return 1
  fi
  log_ok "Golden valid: $(fmt_bytes "$size")"
  return 0
}

auto_fix_golden() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  if golden_is_valid; then
    return 0
  fi
  if [[ -f "$out" ]]; then
    local size
    size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
    log_warn "Auto-fix: hapus golden rusak ($(fmt_bytes "$size"))..."
    rm -f "$out"
  fi
  return 1
}

data_img_is_valid() {
  local img="$INSTALL_DIR/windows/data.img"
  [[ -f "$img" ]] || return 1
  local size
  size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
  if (( size < DATA_IMG_MIN_BYTES )); then
    log_warn "data.img terlalu kecil: $(fmt_bytes "$size")"
    return 1
  fi
  log_ok "data.img valid: $(fmt_bytes "$size")"
  return 0
}

auto_fix_restore() {
  local attempt max=2
  for attempt in $(seq 1 "$max"); do
    log_info "Restore attempt $attempt/$max..."
    auto_fix_container
    rm -rf "$INSTALL_DIR/windows"
    mkdir -p "$INSTALL_DIR/windows" "$INSTALL_DIR/shared"
    log_info "Extracting golden → windows/ (bisa 2-5 menit)..."
    tar -xzf "$INSTALL_DIR/golden/$GOLDEN_FILE" -C "$INSTALL_DIR" 2>&1 | tee -a "$LOG_FILE"
    if [[ ${PIPESTATUS[0]} -eq 0 ]] && data_img_is_valid; then
        log_ok "Restore berhasil"
        return 0
    fi
    log_warn "Auto-fix: restore gagal, coba ulang..."
    auto_fix_disk
    sleep 2
  done
  log_err "Restore gagal setelah $max attempt. Cek disk & golden file."
  exit 1
}

dump_system_info() {
  log_info "──── System Info ────"
  log_info "Hostname : $(hostname)"
  log_info "IP       : $(hostname -I 2>/dev/null || echo n/a)"
  log_info "OS       : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -a)"
  log_info "Kernel   : $(uname -r)"
  log_info "CPU      : $(nproc) core — $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | xargs || echo n/a)"
  log_info "RAM      : $(free -h 2>/dev/null | awk '/Mem:/{print $2" total, "$7" available"}' || echo n/a)"
  log_info "Disk     : $(df -h / | tail -1 | awk '{print $2" total, "$4" free ("$5" used)"}')"
  log_info "KVM      : $([ -e /dev/kvm ] && echo 'OK (/dev/kvm ada)' || echo 'TIDAK ADA')"
  if grep -qE 'vmx|svm' /proc/cpuinfo 2>/dev/null; then
    log_ok "CPU virtualization flag: $(grep -oE 'vmx|svm' /proc/cpuinfo | head -1)"
  else
    log_warn "CPU virtualization flag tidak terdeteksi"
  fi
  log_info "Install  : $INSTALL_DIR"
  log_info "Golden   : $GOLDEN_URL"
  log_info "Log file : $LOG_FILE"
  log_info "────────────────────"
}

download_golden() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  mkdir -p "$INSTALL_DIR/golden"

  if golden_is_valid; then
    log_ok "Skip download — golden sudah valid"
    return 0
  fi

  auto_fix_golden || true
  auto_fix_disk
  auto_fix_aria2

  log_info "Mulai download golden (~5.5 GB)..."
  log_info "URL: $GOLDEN_URL"

  if command -v aria2c &>/dev/null; then
    log_info "Metode: aria2 (16 koneksi, resume OK)"
    aria2c -x 16 -s 16 -k 1M -c --file-allocation=none \
      --summary-interval=30 \
      -d "$INSTALL_DIR/golden" -o "$GOLDEN_FILE" "$GOLDEN_URL" \
      2>&1 | tee -a "$LOG_FILE"
  else
    log_info "Metode: wget (fallback single-thread)"
    wget -c --progress=dot:giga -O "$out" "$GOLDEN_URL" 2>&1 | tee -a "$LOG_FILE"
  fi

  if ! golden_is_valid; then
    log_err "Download selesai tapi golden masih invalid/corrupt"
    exit 1
  fi
  log_ok "Download golden selesai: $(fmt_bytes "$(stat -c%s "$out")")"
}

build_image() {
  if docker image inspect "$IMAGE" &>/dev/null; then
    local img_id img_size
    img_id=$(docker image inspect "$IMAGE" --format '{{.Id}}' | cut -c8-19)
    img_size=$(docker image inspect "$IMAGE" --format '{{.Size}}' 2>/dev/null || echo 0)
    log_ok "Skip build — image sudah ada ($img_id, $(fmt_bytes "$img_size"))"
    return 0
  fi
  log_info "Build Docker image (pertama kali, bisa 2-5 menit)..."
  docker build -t "$IMAGE" . 2>&1 | tee -a "$LOG_FILE"
  log_ok "Build selesai: $IMAGE"
}

verify_windows() {
  local retries=6 i
  log_info "Verifikasi Windows container..."
  for i in $(seq 1 "$retries"); do
    if docker ps --format '{{.Names}} {{.Status}}' | grep -q "^${CONTAINER} Up"; then
      log_ok "Container $CONTAINER running"
      if docker logs "$CONTAINER" 2>&1 | tail -20 | tee -a "$LOG_FILE" | grep -qi 'started successfully\|Booting Windows'; then
        log_ok "Windows boot terdeteksi di log"
      else
        log_info "Windows masih booting... ($i/$retries)"
      fi
      docker compose -f "$COMPOSE" ps 2>&1 | tee -a "$LOG_FILE"
      return 0
    fi
    log_info "Menunggu container... ($i/$retries)"
    sleep 10
  done
  log_warn "Container belum confirmed running — cek: docker logs $CONTAINER"
  docker logs "$CONTAINER" --tail 30 2>&1 | tee -a "$LOG_FILE" || true
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || { log_err "Jalankan sebagai root (sudo bash)"; exit 1; }

echo ""
echo "=========================================="
echo " Ghost Spectre Golden — Fast Setup"
echo " Log: $LOG_FILE"
echo "=========================================="
echo ""

log_info "========== INSTALL MULAI =========="
dump_system_info

# [1/7] KVM
step "Cek KVM (nested virtualization)"
if [[ ! -e /dev/kvm ]]; then
  log_err "/dev/kvm tidak ada — VPS tidak support nested virtualization"
  log_info "Ganti ke VPS: DigitalOcean Droplet / Hetzner / AWS C8i+M8i+R8i (nested virt ON)"
  exit 1
fi
log_ok "KVM OK — /dev/kvm tersedia"

# [2/7] Docker
step "Install Docker"
if ! command -v docker &>/dev/null; then
  log_info "Docker belum ada, install via get.docker.com..."
  export DEBIAN_FRONTEND=noninteractive
  curl -fsSL https://get.docker.com | sh 2>&1 | tee -a "$LOG_FILE"
  log_ok "Docker terinstall"
else
  log_ok "Docker sudah ada: $(docker --version)"
fi
docker compose version 2>&1 | tee -a "$LOG_FILE" || docker-compose --version 2>&1 | tee -a "$LOG_FILE" || true

# [3/7] Repo
step "Clone / update repo"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  log_info "Repo ada, git pull..."
  git -C "$INSTALL_DIR" pull origin master 2>&1 | tee -a "$LOG_FILE"
else
  log_info "Clone baru dari $REPO ..."
  rm -rf "$INSTALL_DIR"
  git clone "$REPO" "$INSTALL_DIR" 2>&1 | tee -a "$LOG_FILE"
fi
cd "$INSTALL_DIR"
chmod +x scripts/*.sh 2>/dev/null || true
log_ok "Repo ready: $INSTALL_DIR ($(git rev-parse --short HEAD 2>/dev/null || echo unknown))"

# [4/7] Build
step "Build Docker image"
auto_fix_disk
build_image

# [5/7] Download
step "Download golden image (~5.5 GB)"
log_info "Tip: GOLDEN_URL=https://... untuk mirror lebih cepat"
download_golden

# [6/7] Restore
step "Restore golden image"
auto_fix_disk
auto_fix_restore

# [7/7] Start
step "Start Windows"
auto_fix_container
log_info "docker compose up -d ..."
docker compose -f "$COMPOSE" up -d 2>&1 | tee -a "$LOG_FILE"
verify_windows

IP=$(hostname -I | awk '{print $1}')

echo ""
log_info "========== INSTALL SELESAI ($(elapsed)) =========="
echo ""
echo "=========================================="
echo " SELESAI — Windows siap pakai!"
echo "=========================================="
echo "  Web viewer : http://${IP}:8006"
echo "  RDP tunnel : ssh -N -L 13389:127.0.0.1:8007 root@${IP}"
echo "  RDP connect: localhost:13389"
echo "  User       : Administrator"
echo "  Password   : 12345678"
echo "  Log file   : $LOG_FILE"
echo "=========================================="
echo ""
