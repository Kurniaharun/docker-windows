#!/bin/bash
# Fast setup — VPS kosong → Windows Ghost Spectre golden (zero manual setup)
# Usage: curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/install.sh | bash

set -euo pipefail

GOLDEN_URL="${GOLDEN_URL:-https://archive.org/download/windows-golden.tar/windows-golden.tar.gz}"
GOLDEN_MIN_BYTES="${GOLDEN_MIN_BYTES:-5000000000}"
GOLDEN_FILE="windows-golden.tar.gz"
DATA_IMG_MIN_BYTES="${DATA_IMG_MIN_BYTES:-8000000000}"
DISK_MIN_FREE_KB="${DISK_MIN_FREE_KB:-25000000}"
REPO="${REPO:-https://github.com/Kurniaharun/docker-windows.git}"
INSTALL_DIR="${INSTALL_DIR:-/root/docker-windows}"
COMPOSE="compose.ghostspectre.yml"
IMAGE="dockurr/windows:ghostspectre"
CONTAINER="windows"
LOG_FILE="${LOG_FILE:-/var/log/ghostspectre-install.log}"
STEP=0
TOTAL_STEPS=7
START_TS=$(date +%s)

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="${INSTALL_DIR}/install.log"

# ── Console + log (selalu tampil di terminal, tidak blank) ───────────────────

_ts() { date '+%Y-%m-%d %H:%M:%S'; }

_to_log() { echo "$1" >> "$LOG_FILE"; }

# Pesan besar di console + log
say() {
  echo "$*"
  _to_log "[$(_ts)] $*"
}

say_blank() {
  echo ""
  _to_log "[$(_ts)]"
}

# Detail teknis (console + log)
log_info()  { say "[INFO]  $*"; }
log_ok()    { say "[ OK ]  $*"; }
log_warn()  { say "[WARN]  $*"; }
log_err()   { say "[ERROR] $*"; }

banner() {
  say_blank
  say "╔══════════════════════════════════════════════════════════════╗"
  printf '%s\n' "$1" | while IFS= read -r line; do
    say "║  $(printf '%-58s' "$line")║"
  done
  say "╚══════════════════════════════════════════════════════════════╝"
  say_blank
}

step() {
  STEP=$((STEP + 1))
  banner "[${STEP}/${TOTAL_STEPS}] $*"
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
  say_blank
  log_err "GAGAL di baris $1 (waktu: $(elapsed))"
  log_err "Log lengkap: $LOG_FILE"
  say ""
  say "Tips perbaikan:"
  say "  rm -f $INSTALL_DIR/golden/$GOLDEN_FILE   # golden corrupt"
  say "  df -h /                                   # cek disk (~25GB kosong)"
  say "  tail -50 $LOG_FILE                        # lihat error detail"
  exit 1
}
trap 'on_error $LINENO' ERR

# Docker build: tampilkan setiap layer di console (progress=plain)
run_docker_build() {
  say ">>> SEDANG: Build image Docker ($IMAGE)"
  say "    Pertama kali ~2-5 menit. Layer muncul di bawah:"
  say "    Waktu: $(elapsed) — JANGAN TUTUP TERMINAL"
  say_blank

  export DOCKER_BUILDKIT=1
  docker build --progress=plain -t "$IMAGE" . 2>&1 | while IFS= read -r line; do
    echo "    | $line"
    _to_log "[$(_ts)] [BUILD] $line"
  done

  log_ok "Build image selesai: $IMAGE"
}

# Extract tar: tampilkan ukuran data.img naik di console
run_tar_extract() {
  local archive="$1"
  say ">>> SEDANG: Extract golden image → data.img Windows"
  say "    File: $GOLDEN_FILE (~5.5 GB terkompresi → ~17 GB data.img)"
  say "    Estimasi: 2-5 menit — INI NORMAL kalau terlihat 'diam'"
  say "    Waktu: $(elapsed) — JANGAN TUTUP TERMINAL"
  say_blank

  tar -xzf "$archive" -C "$INSTALL_DIR" >> "$LOG_FILE" 2>&1 &
  local pid=$!
  local spin='|/-\' i=0 last_size=0

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    local size_str=""
    if [[ -f "$INSTALL_DIR/windows/data.img" ]]; then
      local sz
      sz=$(stat -c%s "$INSTALL_DIR/windows/data.img" 2>/dev/null || echo 0)
      if (( sz > last_size )); then last_size=$sz; fi
      size_str="data.img: $(fmt_bytes "$last_size") / ~17GB"
    else
      size_str="menyiapkan extract..."
    fi
    printf '\r    [%s] Extract golden — %s — %s   ' "${spin:$i:1}" "$(elapsed)" "$size_str"
    sleep 1
  done

  wait "$pid"
  local rc=$?
  printf '\r%100s\r' ''

  if (( rc != 0 )); then
    log_err "Extract gagal (exit $rc)"
    return "$rc"
  fi
  log_ok "Extract selesai — data.img: $(fmt_bytes "$(stat -c%s "$INSTALL_DIR/windows/data.img")")"
}

# ── Auto-fix ─────────────────────────────────────────────────────────────────

auto_fix_disk() {
  local avail_kb
  avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
  log_info "Cek disk: $(fmt_kb "$avail_kb") tersedia (min $(fmt_kb "$DISK_MIN_FREE_KB"))"
  if (( avail_kb < DISK_MIN_FREE_KB )); then
    say ">>> AUTO-FIX: Disk penuh — bersihkan cache Docker..."
    docker system prune -af --volumes 2>/dev/null | tee -a "$LOG_FILE" || true
    apt-get clean 2>/dev/null || true
    avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
    log_info "Disk setelah cleanup: $(fmt_kb "$avail_kb")"
    if (( avail_kb < DISK_MIN_FREE_KB )); then
      log_err "Disk tidak cukup (~25GB kosong dibutuhkan)"
      exit 1
    fi
    log_ok "Auto-fix disk berhasil"
  else
    log_ok "Disk cukup"
  fi
}

auto_fix_container() {
  say ">>> AUTO-FIX: Stop container Windows lama (jika ada)..."
  docker compose -f "$INSTALL_DIR/$COMPOSE" down 2>/dev/null | tee -a "$LOG_FILE" || true
  docker rm -f "$CONTAINER" 2>/dev/null | tee -a "$LOG_FILE" || true
  log_ok "Container lama dibersihkan"
}

auto_fix_aria2() {
  if command -v aria2c &>/dev/null; then
    log_ok "aria2 siap (download cepat 16 koneksi)"
    return 0
  fi
  say ">>> AUTO-FIX: Install aria2 untuk download lebih cepat..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq 2>&1 | tee -a "$LOG_FILE"
  apt-get install -y -qq aria2 2>&1 | tee -a "$LOG_FILE"
  log_ok "aria2 terinstall"
}

golden_is_valid() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  [[ -f "$out" ]] || return 1
  local size
  size=$(stat -c%s "$out" 2>/dev/null || stat -f%z "$out")
  if (( size < GOLDEN_MIN_BYTES )); then
    log_warn "Golden tidak lengkap: $(fmt_bytes "$size") — butuh ~5.5GB"
    return 1
  fi
  say ">>> SEDANG: Validasi checksum golden (gzip test)..."
  if ! gzip -t "$out" 2>/dev/null; then
    log_warn "Golden corrupt (gzip gagal)"
    return 1
  fi
  log_ok "Golden valid: $(fmt_bytes "$size")"
  return 0
}

auto_fix_golden() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  if golden_is_valid; then return 0; fi
  if [[ -f "$out" ]]; then
    say ">>> AUTO-FIX: Hapus golden rusak/tidak lengkap..."
    rm -f "$out"
    log_ok "File golden lama dihapus — akan download ulang"
  fi
  return 1
}

data_img_is_valid() {
  local img="$INSTALL_DIR/windows/data.img"
  [[ -f "$img" ]] || { log_warn "data.img belum ada"; return 1; }
  local size
  size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
  if (( size < DATA_IMG_MIN_BYTES )); then
    log_warn "data.img terlalu kecil: $(fmt_bytes "$size")"
    return 1
  fi
  log_ok "data.img OK: $(fmt_bytes "$size")"
  return 0
}

auto_fix_restore() {
  local attempt max=2
  for attempt in $(seq 1 "$max"); do
    banner "RESTORE WINDOWS — percobaan $attempt/$max"
    auto_fix_container
    say ">>> SEDANG: Hapus folder windows lama..."
    rm -rf "$INSTALL_DIR/windows"
    mkdir -p "$INSTALL_DIR/windows" "$INSTALL_DIR/shared"
    run_tar_extract "$INSTALL_DIR/golden/$GOLDEN_FILE"
    if data_img_is_valid; then
      log_ok "Restore Windows berhasil"
      return 0
    fi
    log_warn "Restore gagal — auto-fix retry..."
    auto_fix_disk
    sleep 2
  done
  log_err "Restore gagal setelah $max percobaan"
  exit 1
}

dump_system_info() {
  say "──── Info VPS ────"
  say "  Hostname : $(hostname)"
  say "  IP       : $(hostname -I 2>/dev/null | awk '{print $1}' || echo n/a)"
  say "  OS       : $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -a)"
  say "  CPU/RAM  : $(nproc) core | $(free -h 2>/dev/null | awk '/Mem:/{print $2" RAM"}')"
  say "  Disk     : $(df -h / | tail -1 | awk '{print $4" kosong / "$2" total"}')"
  say "  KVM      : $([ -e /dev/kvm ] && echo OK || echo TIDAK ADA — VPS tidak support!)"
  say "  Log file : $LOG_FILE"
  say "──────────────────"
}

download_golden() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  mkdir -p "$INSTALL_DIR/golden"

  if golden_is_valid; then
    say ">>> Golden sudah ada & valid — SKIP download"
    return 0
  fi

  auto_fix_golden || true
  auto_fix_disk
  auto_fix_aria2

  banner "DOWNLOAD GOLDEN IMAGE (~5.5 GB)"
  say "  URL: $GOLDEN_URL"
  say "  Estimasi: 5-30 menit (aria2 ~2-5 menit)"
  say_blank

  if command -v aria2c &>/dev/null; then
    say ">>> SEDANG: Download via aria2 (16 koneksi)..."
    say "    Progress muncul di bawah setiap 30 detik"
    say_blank
    aria2c -x 16 -s 16 -k 1M -c --file-allocation=none \
      --summary-interval=10 \
      -d "$INSTALL_DIR/golden" -o "$GOLDEN_FILE" "$GOLDEN_URL" \
      2>&1 | while IFS= read -r line; do
        echo "    | $line"
        _to_log "[$(_ts)] [DL] $line"
      done
  else
    say ">>> SEDANG: Download via wget..."
    wget -c --progress=bar:force -O "$out" "$GOLDEN_URL" 2>&1 | while IFS= read -r line; do
      echo "    | $line"
      _to_log "[$(_ts)] [DL] $line"
    done
  fi

  say_blank
  say ">>> Download selesai — validasi file..."
  golden_is_valid || { log_err "Download gagal / file corrupt"; exit 1; }
  say ""
  say "╔══════════════════════════════════════════════════════════════╗"
  say "║  DOWNLOAD SELESAI! Lanjut extract & install Windows...       ║"
  say "╚══════════════════════════════════════════════════════════════╝"
}

build_image() {
  if docker image inspect "$IMAGE" &>/dev/null; then
    log_ok "Image Docker sudah ada — SKIP build ($IMAGE)"
    return 0
  fi
  run_docker_build
}

verify_windows() {
  local retries=12 i
  banner "BOOT WINDOWS — menunggu VM siap"
  say ">>> SEDANG: Windows boot di dalam Docker (~1-3 menit)"
  say "    Container: $CONTAINER"
  say_blank

  for i in $(seq 1 "$retries"); do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
      local status boot_msg
      status=$(docker ps --filter "name=$CONTAINER" --format '{{.Status}}')
      boot_msg=$(docker logs "$CONTAINER" 2>&1 | tail -5 | tr '\n' ' ')
      say "    [$i/$retries] Container: $status"
      if echo "$boot_msg" | grep -qi 'started successfully'; then
        say_blank
        log_ok "Windows SUDAH JALAN!"
        docker logs "$CONTAINER" 2>&1 | tail -8 | while IFS= read -r line; do say "    | $line"; done
        say_blank
        docker compose -f "$COMPOSE" ps
        return 0
      fi
      if echo "$boot_msg" | grep -qi 'Booting Windows\|Resizing disk'; then
        say "    [$i/$retries] VM sedang boot... ($(elapsed))"
      fi
    else
      say "    [$i/$retries] Menunggu container start... ($(elapsed))"
    fi
    sleep 10
  done
  log_warn "Windows mungkin masih boot — cek: docker logs $CONTAINER"
  docker logs "$CONTAINER" --tail 15 2>&1 | while IFS= read -r line; do say "    | $line"; done
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || { log_err "Jalankan sebagai root: sudo bash"; exit 1; }

banner "GHOST SPECTRE — FAST SETUP"
say "  Install Windows dari golden image (VPS kosong → Windows siap)"
say "  Log file: $LOG_FILE"
say "  Waktu mulai: $(_ts)"

dump_system_info

# [1/7] KVM
step "CEK KVM (virtualization)"
if [[ ! -e /dev/kvm ]]; then
  log_err "/dev/kvm TIDAK ADA — VPS tidak support Windows Docker"
  say "  Ganti VPS: DigitalOcean / Hetzner / AWS C8i+M8i+R8i"
  exit 1
fi
log_ok "KVM OK — VPS support Windows Docker"

# [2/7] Docker
step "INSTALL DOCKER"
if ! command -v docker &>/dev/null; then
  say ">>> SEDANG: Install Docker..."
  export DEBIAN_FRONTEND=noninteractive
  curl -fsSL https://get.docker.com | sh 2>&1 | while IFS= read -r line; do
    echo "    | $line"
    _to_log "[$(_ts)] [DOCKER] $line"
  done
  log_ok "Docker terinstall: $(docker --version)"
else
  log_ok "Docker sudah ada: $(docker --version)"
fi

# [3/7] Repo
step "CLONE REPOSITORY"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  say ">>> SEDANG: Update repo (git pull)..."
  git -C "$INSTALL_DIR" pull origin master 2>&1 | while IFS= read -r line; do
    echo "    | $line"
    _to_log "[$(_ts)] [GIT] $line"
  done
else
  say ">>> SEDANG: Clone repo dari GitHub..."
  rm -rf "$INSTALL_DIR"
  git clone "$REPO" "$INSTALL_DIR" 2>&1 | while IFS= read -r line; do
    echo "    | $line"
    _to_log "[$(_ts)] [GIT] $line"
  done
fi
cd "$INSTALL_DIR"
chmod +x scripts/*.sh 2>/dev/null || true
log_ok "Repo siap: $(git rev-parse --short HEAD 2>/dev/null)"

# [4/7] Build
step "BUILD DOCKER IMAGE"
auto_fix_disk
build_image

# [5/7] Download
step "DOWNLOAD GOLDEN IMAGE"
say "  Tip: GOLDEN_URL=https://... untuk mirror lebih cepat"
download_golden

# [6/7] Restore
step "RESTORE WINDOWS (extract data.img)"
auto_fix_disk
auto_fix_restore

# [7/7] Start
step "START WINDOWS CONTAINER"
auto_fix_container
say ">>> SEDANG: docker compose up -d ..."
docker compose -f "$COMPOSE" up -d 2>&1 | while IFS= read -r line; do
  echo "    | $line"
  _to_log "[$(_ts)] [COMPOSE] $line"
done
log_ok "Container started"
verify_windows

IP=$(hostname -I | awk '{print $1}')

say_blank
banner "INSTALL SELESAI — $(elapsed)"
say "  Web viewer : http://${IP}:8006"
say "  RDP tunnel : ssh -N -L 13389:127.0.0.1:8007 root@${IP}"
say "  RDP        : localhost:13389"
say "  User       : Administrator"
say "  Password   : 12345678"
say "  Log        : $LOG_FILE"
say_blank
