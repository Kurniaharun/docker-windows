#!/bin/bash
# Fast setup — VPS kosong → Windows Ghost Spectre golden (zero manual setup)
# Usage (recommended):
#   curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/get.sh | bash
# Atau:
#   git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && bash /root/docker-windows/install.sh

set -euo pipefail

GOLDEN_URL="${GOLDEN_URL:-https://archive.org/download/windows-golden.tar/windows-golden.tar.gz}"
GOLDEN_MIN_BYTES="${GOLDEN_MIN_BYTES:-5000000000}"
GOLDEN_FILE="windows-golden.tar.gz"
DATA_IMG_MIN_BYTES="${DATA_IMG_MIN_BYTES:-8000000000}"
DATA_IMG_MIN_DU_BYTES="${DATA_IMG_MIN_DU_BYTES:-4000000000}"
DISK_MIN_FREE_KB="${DISK_MIN_FREE_KB:-25000000}"
REPO="${REPO:-https://github.com/Kurniaharun/docker-windows.git}"
INSTALL_DIR="${INSTALL_DIR:-/root/docker-windows}"
COMPOSE="compose.ghostspectre.yml"
IMAGE="dockurr/windows:ghostspectre"
CONTAINER="windows"
RDP_PORT="${RDP_PORT:-8007}"
WEB_PORT="${WEB_PORT:-8006}"
LOG_FILE="${LOG_FILE:-/var/log/ghostspectre-install.log}"
STEP=0
TOTAL_STEPS=7
START_TS=$(date +%s)

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="${INSTALL_DIR}/install.log"

# ── UI / Logging (console keren + log file plain) ────────────────────────────

if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
  C0='' C1='' C2='' CR='' CG='' CY='' CB='' CM='' CD=''
  [[ -n "${NO_COLOR:-}" ]] || {
    C0='\033[0m' C1='\033[1m' C2='\033[2m'
    CR='\033[31m' CG='\033[32m' CY='\033[36m' CB='\033[34m' CM='\033[35m' CD='\033[2m'
  }
else
  C0='' C1='' C2='' CR='' CG='' CY='' CB='' CM='' CD=''
fi

_ts()     { date '+%H:%M:%S'; }
_ts_full(){ date '+%Y-%m-%d %H:%M:%S'; }

_to_log() { echo "[$(_ts_full)] $1" >> "$LOG_FILE"; }

# Console (styled) + log file (plain, no ANSI)
_emit() {
  local plain="$1" styled="$2"
  echo -e "$styled"
  _to_log "$plain"
}

say()       { _emit "$*" "${CD}${*}${C0}"; }
say_blank() { echo ""; _to_log ""; }

log_info()  { _emit "INFO  | $*" "${CY}${C1}INFO${C0}  ${CD}|${C0} $*"; }
log_ok()    { _emit "OK    | $*" "${CG}${C1} OK ${C0}  ${CD}|${C0} $*"; }
log_warn()  { _emit "WARN  | $*" "${CY}${C1}WARN${C0}  ${CD}|${C0} $*"; }
log_err()   { _emit "ERROR | $*" "${CR}${C1} ERR${C0}  ${CD}|${C0} $*"; }

log_step()  { _emit "STEP  | $*" "${CB}${C1} >>>${C0} ${C1}$*${C0}"; }
log_sub()   { _emit "      | $*" "${CD}    $*${C0}"; }

hr() {
  echo -e "${CD}──────────────────────────────────────────────────────────────${C0}"
  _to_log "──────────────────────────────────────────────────────────────"
}

banner() {
  local title="$1"
  say_blank
  echo -e "${CB}${C1}┌──────────────────────────────────────────────────────────────┐${C0}"
  _to_log "┌──────────────────────────────────────────────────────────────┐"
  printf '%s\n' "$title" | while IFS= read -r line; do
    echo -e "${CB}${C1}│${C0}  $(printf '%-58s' "$line")${CB}${C1}│${C0}"
    _to_log "│  $(printf '%-58s' "$line")│"
  done
  echo -e "${CB}${C1}└──────────────────────────────────────────────────────────────┘${C0}"
  _to_log "└──────────────────────────────────────────────────────────────┘"
  say_blank
}

step() {
  STEP=$((STEP + 1))
  local pct=$(( STEP * 100 / TOTAL_STEPS ))
  banner "[${STEP}/${TOTAL_STEPS}] ${pct}%  $*"
}

# Satu baris realtime (overwrite) — hanya console, snapshot ke log tiap N detik
_rt_last_log=0
progress_line() {
  local msg="$1"
  printf '\r%b' "    ${CM}${C1}▸${C0} ${msg}   "
  local now
  now=$(date +%s)
  if (( now - _rt_last_log >= 15 )); then
    _to_log "PROG  | $msg"
    _rt_last_log=$now
  fi
}

progress_clear() { printf '\r%100s\r' ''; }

progress_bar() {
  local cur=$1 max=$2 label=$3
  local w=28 pct filled empty bar=""
  [[ "$max" -lt 1 ]] && max=1
  pct=$(( cur * 100 / max ))
  (( pct > 100 )) && pct=100
  filled=$(( pct * w / 100 ))
  empty=$(( w - filled ))
  bar=$(printf "%${filled}s" | tr ' ' '█')
  bar+=$(printf "%${empty}s" | tr ' ' '░')
  progress_line "${label} [${bar}] ${pct}%"
}

# aria2: tampilkan baris progress [#...] saja, format rapi
stream_aria2() {
  local done=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _to_log "DL | $line"
    if [[ "$line" =~ ^\[#[a-f0-9]+[[:space:]] ]]; then
      local clean="${line#\[#* }"
      clean="${clean%\]}"
      progress_line "Download  ${clean}"
    elif (( done == 0 )) && [[ "$line" =~ Download[[:space:]]+[Cc]omplete ]]; then
      done=1
      progress_clear
      log_ok "Download selesai"
    fi
  done
  progress_clear
}

show_summary_box() {
  local ip="$1"
  hr
  echo -e "${CG}${C1}  INSTALL SELESAI${C0}  ${CD}$(elapsed)${C0}"
  hr
  printf "  ${C1}%-12s${C0} %s\n" "IP RDP" "$ip"
  printf "  ${C1}%-12s${C0} %s\n" "PORT RDP" "$RDP_PORT"
  printf "  ${C1}%-12s${C0} %s\n" "Connect" "${ip}:${RDP_PORT}"
  printf "  ${C1}%-12s${C0} %s\n" "User" "Administrator"
  printf "  ${C1}%-12s${C0} %s\n" "Password" "12345678"
  hr
  printf "  ${C1}%-12s${C0} %s\n" "Web" "http://${ip}:${WEB_PORT}"
  printf "  ${C1}%-12s${C0} %s\n" "Log" "$LOG_FILE"
  hr
  echo -e "${CD}  Tunnel (firewall blok): ssh -N -L 13389:127.0.0.1:${RDP_PORT} root@${ip}${C0}"
  say_blank
  _to_log "SUMMARY | IP=${ip} PORT=${RDP_PORT} WEB=${WEB_PORT}"
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

# Bytes benar-benar terpakai di disk (bukan ukuran virtual sparse file)
file_disk_bytes() {
  local f="$1"
  du -b "$f" 2>/dev/null | cut -f1
}

file_virtual_bytes() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

# Auto-detect IP publik VPS (DO metadata → skip private → fallback)
detect_vps_ip() {
  local ip=""
  ip=$(curl -fsS --connect-timeout 2 \
    http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address 2>/dev/null) && {
    echo "$ip"
    return 0
  }
  for ip in $(hostname -I 2>/dev/null); do
    [[ "$ip" =~ ^127\. ]] && continue
    [[ "$ip" =~ ^10\. ]] && continue
    [[ "$ip" =~ ^192\.168\. ]] && continue
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] && continue
    [[ "$ip" == *:* ]] && continue
    echo "$ip"
    return 0
  done
  ip=$(curl -fsS --connect-timeout 3 https://api.ipify.org 2>/dev/null) && {
    echo "$ip"
    return 0
  }
  hostname -I 2>/dev/null | awk '{print $1}'
}

elapsed() {
  local now=$(( $(date +%s) - START_TS ))
  printf '%dm%02ds' $((now / 60)) $((now % 60))
}

on_error() {
  progress_clear
  say_blank
  log_err "Gagal di baris $1  ·  waktu $(elapsed)"
  log_sub "Log: $LOG_FILE"
  hr
  log_sub "rm -f $INSTALL_DIR/golden/$GOLDEN_FILE"
  log_sub "df -h /"
  log_sub "tail -50 $LOG_FILE"
  exit 1
}
trap 'on_error $LINENO' ERR

# Docker build: tampilkan setiap layer di console (progress=plain)
run_docker_build() {
  log_step "Build image Docker"
  log_sub "Image: ${IMAGE}  ·  estimasi 2-5 menit"
  log_sub "Layer build (realtime):"
  hr

  export DOCKER_BUILDKIT=1
  docker build --progress=plain -t "$IMAGE" . 2>&1 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _to_log "BUILD | $line"
    if [[ "$line" =~ ^#[0-9]+ ]]; then
      echo -e "    ${CD}│${C0} $line"
    fi
  done

  log_ok "Build selesai · ${IMAGE}"
}

# Extract tar: progress pakai du (disk nyata), bukan stat (virtual sparse)
run_tar_extract() {
  local archive="$1"
  log_step "Extract golden → data.img"
  log_sub "Archive: ${GOLDEN_FILE}  ·  sparse ~32G virtual"
  log_sub "Progress = disk nyata  ·  estimasi 1-4 menit"
  hr

  if ! command -v pigz &>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -qq pigz 2>/dev/null || true
  fi

  local extract_cmd=()
  if command -v pigz &>/dev/null; then
    log_sub "Engine: pigz + tar sparse"
    extract_cmd=(bash -c "pigz -dc \"${archive}\" | tar -xS -C \"${INSTALL_DIR}\"")
  else
    log_sub "Engine: tar sparse"
    extract_cmd=(tar -xSpf "$archive" -C "$INSTALL_DIR")
  fi

  "${extract_cmd[@]}" >> "$LOG_FILE" 2>&1 &
  local pid=$! last_du=0 target_du=12000000000

  while kill -0 "$pid" 2>/dev/null; do
    if [[ -f "$INSTALL_DIR/windows/data.img" ]]; then
      local du_sz
      du_sz=$(file_disk_bytes "$INSTALL_DIR/windows/data.img")
      du_sz=${du_sz:-0}
      (( du_sz > last_du )) && last_du=$du_sz
      progress_bar "$last_du" "$target_du" "Extract"
    else
      progress_line "Extract  menyiapkan...  $(elapsed)"
    fi
    sleep 1
  done

  wait "$pid"
  local rc=$?
  progress_clear

  if (( rc != 0 )); then
    log_err "Extract gagal (exit $rc) · cek $LOG_FILE"
    return "$rc"
  fi

  local virt du
  virt=$(file_virtual_bytes "$INSTALL_DIR/windows/data.img")
  du=$(file_disk_bytes "$INSTALL_DIR/windows/data.img")
  log_ok "Extract selesai · virtual $(fmt_bytes "$virt") · disk $(fmt_bytes "$du")"
}

# ── Auto-fix ─────────────────────────────────────────────────────────────────

auto_fix_disk() {
  local avail_kb
  avail_kb=$(df --output=avail / | tail -1 | tr -d ' ')
  log_info "Cek disk: $(fmt_kb "$avail_kb") tersedia (min $(fmt_kb "$DISK_MIN_FREE_KB"))"
  if (( avail_kb < DISK_MIN_FREE_KB )); then
    log_warn "Auto-fix: bersihkan cache Docker..."
    docker system prune -af --volumes 2>/dev/null >> "$LOG_FILE" 2>&1 || true
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
  log_sub "Auto-fix: stop container lama..."
  docker compose -f "$INSTALL_DIR/$COMPOSE" down 2>/dev/null >> "$LOG_FILE" 2>&1 || true
  docker rm -f "$CONTAINER" 2>/dev/null >> "$LOG_FILE" 2>&1 || true
  log_ok "Container lama dibersihkan"
}

auto_fix_aria2() {
  if command -v aria2c &>/dev/null; then
    log_ok "aria2 siap (download cepat 16 koneksi)"
    return 0
  fi
  say ">>> AUTO-FIX: Install aria2..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq 2>&1 | tee -a "$LOG_FILE"
  apt-get install -y -qq aria2 2>&1 | tee -a "$LOG_FILE"
  log_ok "aria2 terinstall"
}

golden_is_valid() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  [[ -f "$out" ]] || return 1
  local size
  size=$(file_virtual_bytes "$out")
  if (( size < GOLDEN_MIN_BYTES )); then
    log_warn "Golden tidak lengkap: $(fmt_bytes "$size") — butuh ~5.5GB"
    return 1
  fi
  log_ok "Golden valid (cek ukuran): $(fmt_bytes "$size")"
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
  local virt du
  virt=$(file_virtual_bytes "$img")
  du=$(file_disk_bytes "$img")
  du=${du:-0}
  if (( virt < DATA_IMG_MIN_BYTES && du < DATA_IMG_MIN_DU_BYTES )); then
    log_warn "data.img belum lengkap — virtual: $(fmt_bytes "$virt") disk: $(fmt_bytes "$du")"
    return 1
  fi
  log_ok "data.img OK — virtual: $(fmt_bytes "$virt") | disk: $(fmt_bytes "$du")"
  return 0
}

auto_fix_restore() {
  local attempt max=2
  for attempt in $(seq 1 "$max"); do
    banner "RESTORE WINDOWS — percobaan $attempt/$max"
    auto_fix_container
    log_sub "Hapus folder windows lama..."
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
  hr
  log_info "System check"
  printf "  ${CD}%-10s${C0} %s\n" "Host" "$(hostname)"
  printf "  ${CD}%-10s${C0} %s\n" "IP" "$(detect_vps_ip)"
  printf "  ${CD}%-10s${C0} %s\n" "OS" "$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -a)"
  printf "  ${CD}%-10s${C0} %s\n" "CPU/RAM" "$(nproc) core · $(free -h 2>/dev/null | awk '/Mem:/{print $2}')"
  printf "  ${CD}%-10s${C0} %s\n" "Disk" "$(df -h / | tail -1 | awk '{print $4" free / "$2}')"
  printf "  ${CD}%-10s${C0} %s\n" "KVM" "$([ -e /dev/kvm ] && echo OK || echo TIDAK ADA)"
  printf "  ${CD}%-10s${C0} %s\n" "Log" "$LOG_FILE"
  hr
  _to_log "SYS | host=$(hostname) ip=$(detect_vps_ip)"
}

download_golden() {
  local out="$INSTALL_DIR/golden/$GOLDEN_FILE"
  mkdir -p "$INSTALL_DIR/golden"

  if golden_is_valid; then
    log_ok "Golden sudah ada — skip download"
    return 0
  fi

  auto_fix_golden || true
  auto_fix_disk
  auto_fix_aria2

  banner "DOWNLOAD GOLDEN  ~5.5 GB"
  log_sub "URL: ${GOLDEN_URL}"
  log_sub "Engine: aria2 · 16 koneksi"
  hr

  if command -v aria2c &>/dev/null; then
    aria2c -x 16 -s 16 -k 1M -c --file-allocation=none \
      --summary-interval=5 \
      -d "$INSTALL_DIR/golden" -o "$GOLDEN_FILE" "$GOLDEN_URL" \
      2>&1 | stream_aria2
  else
    log_step "Download via wget..."
    wget -c --progress=bar:force -O "$out" "$GOLDEN_URL" 2>&1 | while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      _to_log "DL | $line"
      echo -e "    ${CD}│${C0} $line"
    done
  fi

  log_sub "Validasi ukuran..."
  golden_is_valid || { log_err "Download gagal / tidak lengkap"; exit 1; }
  banner "DOWNLOAD OK  →  lanjut extract"
}

build_image() {
  if docker image inspect "$IMAGE" &>/dev/null; then
    log_ok "Image Docker sudah ada — SKIP build ($IMAGE)"
    return 0
  fi
  run_docker_build
}

verify_windows() {
  local retries=12 i state=""
  banner "BOOT WINDOWS"
  log_sub "Menunggu VM siap · estimasi 1-3 menit"
  hr

  for i in $(seq 1 "$retries"); do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
      local boot_msg
      boot_msg=$(docker logs "$CONTAINER" 2>&1 | tail -8 | tr '\n' ' ')
      if echo "$boot_msg" | grep -qi 'started successfully'; then
        progress_clear
        log_ok "Windows jalan!"
        hr
        docker logs "$CONTAINER" 2>&1 | tail -6 | while IFS= read -r line; do
          log_sub "$line"
        done
        hr
        docker compose -f "$COMPOSE" ps
        return 0
      fi
      if echo "$boot_msg" | grep -qi 'Resizing disk'; then
        state="resize disk"
      elif echo "$boot_msg" | grep -qi 'Booting Windows'; then
        state="boot QEMU"
      else
        state="starting"
      fi
      progress_line "Boot  [$i/$retries]  $state  ·  $(elapsed)"
    else
      progress_line "Boot  [$i/$retries]  tunggu container  ·  $(elapsed)"
    fi
    sleep 10
  done

  progress_clear
  log_warn "Boot belum confirmed — cek: docker logs $CONTAINER"
  docker logs "$CONTAINER" --tail 10 2>&1 | while IFS= read -r line; do log_sub "$line"; done
}

# ── Main ─────────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || { log_err "Jalankan sebagai root: sudo bash"; exit 1; }

banner "GHOST SPECTRE  ·  FAST SETUP"
log_sub "Golden image → Windows siap pakai"
log_sub "Mulai $(_ts_full)"
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
  log_step "Install Docker..."
  export DEBIAN_FRONTEND=noninteractive
  curl -fsSL https://get.docker.com | sh 2>&1 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _to_log "DOCKER | $line"
    echo -e "    ${CD}│${C0} $line"
  done
  log_ok "Docker · $(docker --version | awk '{print $3}' | tr -d ',')"
else
  log_ok "Docker · $(docker --version | awk '{print $3}' | tr -d ',')"
fi

# [3/7] Repo
step "CLONE REPOSITORY"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  log_step "Update repo..."
  git -C "$INSTALL_DIR" pull origin master 2>&1 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _to_log "GIT | $line"
    echo -e "    ${CD}│${C0} $line"
  done
else
  log_step "Clone repo..."
  rm -rf "$INSTALL_DIR"
  git clone --depth 1 "$REPO" "$INSTALL_DIR" 2>&1 | while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    _to_log "GIT | $line"
    echo -e "    ${CD}│${C0} $line"
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
step "DOWNLOAD GOLDEN"
log_sub "Tip: GOLDEN_URL=... untuk mirror cepat"
download_golden

# [6/7] Restore
step "RESTORE WINDOWS (extract data.img)"
auto_fix_disk
auto_fix_restore

# [7/7] Start
step "START WINDOWS CONTAINER"
auto_fix_container
log_step "Start container..."
docker compose -f "$COMPOSE" up -d 2>&1 | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  _to_log "COMPOSE | $line"
  echo -e "    ${CD}│${C0} $line"
done
log_ok "Container up"
verify_windows

IP=$(detect_vps_ip)
show_summary_box "$IP"
