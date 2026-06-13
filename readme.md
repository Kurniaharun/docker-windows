<h1 align="center">Windows<br />
<div align="center">
<a href="https://github.com/dockur/windows"><img src="https://github.com/dockur/windows/raw/master/.github/logo.png" title="Logo" style="max-width:100%;" width="128" /></a>
</div>
<div align="center">

[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Package]][pkg_url]
[![Pulls]][hub_url]

</div></h1>

Windows inside a Docker container.

> **Fork mod by [kurniaharun](https://github.com/kurniaharun)** — based on [dockur/windows](https://github.com/dockur/windows)
>
> - Auto-download **Ghost Spectre** Win10/Win11 from archive.org (`VERSION: gs10` / `gs11`)
> - Default user **`KurrXd`** / password **`admin`** for official Windows (10/11/LTSC, dll.)
> - **Ghost Spectre** pakai install manual — set **`Administrator`** / **`12345678`** saat setup installer
> - Bat **Enable-RDP**, **Open-Shared**, **RDP-Connect-Help** otomatis di **Desktop** setelah login pertama
> - Panduan lengkap: **[SETUP-FULL.md](SETUP-FULL.md)** | Restore: **[RESTORE.md](RESTORE.md)**

## Fast Setup — 1 Command (VPS kosong → Windows siap pakai)

```bash
curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/get.sh | bash
```

Alternatif (langsung dari git, tanpa CDN):
```bash
git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && bash /root/docker-windows/install.sh
```

Golden image (~5.5 GB) diunduh otomatis dari archive.org. **Tanpa install Windows, tanpa setup user, tanpa masuk RDP.**

Log lengkap: `/var/log/ghostspectre-install.log` — console menampilkan status **SEDANG: ...** tiap step (extract/build/boot tidak blank).

| Setelah selesai | |
|---|---|
| IP RDP | `IP_VPS` |
| PORT RDP | `8007` |
| Connect | `IP_VPS:8007` → `Administrator` / `12345678` |
| Web | `http://IP_VPS:8006` |
| Tunnel (jika firewall blok) | `ssh -N -L 13389:127.0.0.1:8007 root@IP_VPS` → `localhost:13389` |

---

## Perintah Install — 1 Baris (Standalone)

Jalankan di **VPS Linux root** dengan KVM (`/dev/kvm`). Semua command di bawah sudah include install Docker + clone repo.

> **Login setelah selesai**
> | Mode | User | Pass | RDP |
> |---|---|---|---|
> | Golden / Ghost Spectre | `Administrator` | `12345678` | `IP:8007` |
> | Windows resmi (auto) | `KurrXd` | `admin` | `IP:3389` |

### Ghost Spectre — Golden Image (boot langsung, tanpa install)

Windows sudah jadi — download golden ~5.5 GB, extract `data.img`, langsung boot.

| Versi | Command |
|---|---|
| **GS11** (default) | `curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/get.sh \| bash` |
| **GS11** (alternatif git) | `git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && bash /root/docker-windows/install.sh` |
| **GS11** (mirror golden) | `GOLDEN_URL=https://YOUR-MIRROR/windows-golden.tar.gz bash -c 'curl -fsSL https://raw.githubusercontent.com/Kurniaharun/docker-windows/master/get.sh \| bash'` |

> Golden image saat ini = **Ghost Spectre 11** siap pakai. Untuk GS10 golden, backup sendiri via `./scripts/backup-golden.sh` lalu restore.

---

### Ghost Spectre — Fresh Install (download ISO otomatis dari archive.org)

Install manual via web viewer `http://IP:8006` — set **`Administrator`** / **`12345678`** saat setup.

| Versi | Command |
|---|---|
| **GS11** | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker compose -f compose.ghostspectre.yml up -d` |
| **GS10** | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker compose -f compose.ghostspectre10.yml up -d` |

---

### Ghost Spectre — Fresh Install (ISO lokal / file ISO langsung)

Ganti `/root/win.iso` dengan path ISO kamu di VPS. ISO **tidak** didownload — langsung mount ke `/boot.iso`.

| Versi | Command |
|---|---|
| **GS11** (file ISO) | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 8007:3389/tcp -p 8007:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/shared:/shared -v /root/docker-windows/oem:/oem -v /root/win.iso:/boot.iso -e RAM_SIZE=6G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows:ghostspectre` |
| **GS10** (file ISO) | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 8007:3389/tcp -p 8007:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/shared:/shared -v /root/docker-windows/oem:/oem -v /root/win.iso:/boot.iso -e RAM_SIZE=6G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows:ghostspectre` |
| **GS11** (URL ISO langsung) | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 8007:3389/tcp -p 8007:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/shared:/shared -v /root/docker-windows/oem:/oem -e VERSION="https://archive.org/download/ghost-spectre-windows-11/WIN11.PRO.21H2.SUPERLITE%2BCOMPACT.X64.%28WPE%29%20%281%29.ISO" -e RAM_SIZE=6G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows:ghostspectre` |
| **GS10** (URL ISO langsung) | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 8007:3389/tcp -p 8007:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/shared:/shared -v /root/docker-windows/oem:/oem -e VERSION="https://archive.org/download/ghost-spectre-windows-10/2009.SUPERLITE%2BCOMPACT.X64.U2.GHOSTSPECTRE.%28N%29.ISO" -e RAM_SIZE=6G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows:ghostspectre` |

---

### Windows Resmi & Lainnya — Fresh Install (auto download ISO)

Install otomatis via autounattend. User default: **`KurrXd`** / **`admin`**. RDP port **3389**.

Ganti `VERSION=XX` sesuai tabel. Image: `dockurr/windows` (tanpa build).

| VERSION | Windows | Command (1 baris) |
|---|---|---|
| `11` | Windows 11 Pro | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=11 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `11l` | Windows 11 LTSC | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=11l -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `11e` | Windows 11 Enterprise | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=11e -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `10` | Windows 10 Pro | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=10 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `10l` | Windows 10 LTSC | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=10l -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `10e` | Windows 10 Enterprise | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=10e -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `8e` | Windows 8.1 Enterprise | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=8e -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `7u` | Windows 7 Ultimate | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=7u -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `vu` | Windows Vista Ultimate | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=vu -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `xp` | Windows XP Pro | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=xp -e RAM_SIZE=2G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows` |
| `2k` | Windows 2000 Pro | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2k -e RAM_SIZE=2G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows` |
| `2025` | Windows Server 2025 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2025 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2022` | Windows Server 2022 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2022 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2019` | Windows Server 2019 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2019 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2016` | Windows Server 2016 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2016 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2012` | Windows Server 2012 R2 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2012 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2008` | Windows Server 2008 R2 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2008 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `2003` | Windows Server 2003 R2 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=2003 -e RAM_SIZE=2G -e CPU_CORES=2 -e DISK_SIZE=32G --stop-timeout 120 --restart always dockurr/windows` |
| `tiny11` | Tiny 11 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=tiny11 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `tiny10` | Tiny 10 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=tiny10 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `core11` | Core 11 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=core11 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| `nano11` | Nano 11 | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION=nano11 -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |

---

### Windows Resmi — Fresh Install (ISO lokal / URL custom)

Mount file ISO ke `/boot.iso` — **VERSION diabaikan** saat `/boot.iso` ada.

| Mode | Command |
|---|---|
| **File ISO lokal** | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -v /root/win.iso:/boot.iso -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |
| **URL ISO custom** | `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker run -d --name windows --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -p 8006:8006 -p 3389:3389/tcp -p 3389:3389/udp -v /root/docker-windows/windows:/storage -v /root/docker-windows/oem:/oem -e VERSION="https://example.com/win.iso" -e RAM_SIZE=4G -e CPU_CORES=2 -e DISK_SIZE=64G --stop-timeout 120 --restart always dockurr/windows` |

---

### Restore Golden Manual (sudah punya `windows-golden.tar.gz`)

| Command |
|---|
| `curl -fsSL https://get.docker.com \| sh && git clone --depth 1 https://github.com/Kurniaharun/docker-windows.git /root/docker-windows && cd /root/docker-windows && docker build -t dockurr/windows:ghostspectre . && wget -O golden/windows-golden.tar.gz "https://archive.org/download/windows-golden.tar/windows-golden.tar.gz" && chmod +x scripts/*.sh && ./scripts/restore-golden.sh && docker compose -f compose.ghostspectre.yml up -d` |

---

## Features ✨

 - ISO downloader
 - KVM acceleration
 - Web-based viewer

## Video 📺

[![Youtube](https://img.youtube.com/vi/xhGYobuG508/maxresdefault.jpg)](https://www.youtube.com/watch?v=xhGYobuG508)

## Usage 🐳

##### Via Docker Compose:

```yaml
services:
  windows:
    image: dockurr/windows
    container_name: windows
    environment:
      VERSION: "11"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 8006:8006
      - 3389:3389/tcp
      - 3389:3389/udp
    volumes:
      - ./windows:/storage
    restart: always
    stop_grace_period: 2m
```

##### Via Docker CLI:

```bash
docker run -it --rm --name windows -e "VERSION=11" -p 8006:8006 --device=/dev/kvm --device=/dev/net/tun --cap-add NET_ADMIN -v "${PWD:-.}/windows:/storage" --stop-timeout 120 docker.io/dockurr/windows
```

##### Via Kubernetes:

```shell
kubectl apply -f https://raw.githubusercontent.com/dockur/windows/refs/heads/master/kubernetes.yml
```

##### Via Github Codespaces:

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dockur/windows)

##### Via a graphical installer:

[![Download WinBoat](https://github.com/dockur/windows/raw/master/.github/winboat.png)](https://winboat.app)

## FAQ 💬

### How do I use it?

  Very simple! These are the steps:
  
  - Start the container and connect to [port 8006](http://127.0.0.1:8006/) using your web browser.

  - Sit back and relax while the magic happens, the whole installation will be performed fully automatic.

  - Once you see the desktop, your Windows installation is ready for use.
  
  Enjoy your brand new machine, and don't forget to star this repo!

### How do I select the Windows version?

  By default, Windows 11 Pro will be installed. But you can add the `VERSION` environment variable to your compose file, in order to specify an alternative Windows version to be downloaded:

  ```yaml
  environment:
    VERSION: "11"
  ```

  Select from the values below:
  
  | **Value** | **Version**            | **Size** |
  |---|---|---|
  | `11`   | Windows 11 Pro            | 7.9 GB   |
  | `11l`  | Windows 11 LTSC           | 4.7 GB   |
  | `11e`  | Windows 11 Enterprise     | 6.6 GB   |
  ||||
  | `10`   | Windows 10 Pro            | 5.7 GB   |
  | `10l`  | Windows 10 LTSC           | 4.6 GB   |
  | `10e`  | Windows 10 Enterprise     | 5.2 GB   |
  ||||
  | `8e`   | Windows 8.1 Enterprise    | 3.7 GB   |
  | `7u`   | Windows 7 Ultimate        | 3.1 GB   |
  | `vu`   | Windows Vista Ultimate    | 3.0 GB   |
  | `xp`   | Windows XP Professional   | 0.6 GB   |
  | `2k`   | Windows 2000 Professional | 0.4 GB   | 
  ||||  
  | `2025` | Windows Server 2025       | 7.6 GB   |
  | `2022` | Windows Server 2022       | 6.0 GB   |
  | `2019` | Windows Server 2019       | 5.3 GB   |
  | `2016` | Windows Server 2016       | 6.5 GB   |
  | `2012` | Windows Server 2012       | 4.3 GB   |
  | `2008` | Windows Server 2008       | 3.0 GB   |
  | `2003` | Windows Server 2003       | 0.6 GB   |

> [!TIP]
> To install ARM64 versions of Windows use [dockur/windows-arm](https://github.com/dockur/windows-arm/).

### How do I change the storage location?

  To change the storage location, include the following bind mount in your compose file:

  ```yaml
  volumes:
    - ./windows:/storage
  ```

  Replace the example path `./windows` with the desired storage folder or named volume.

### How do I change the size of the disk?

  To expand the default size of 64 GB, add the `DISK_SIZE` setting to your compose file and set it to your preferred capacity:

  ```yaml
  environment:
    DISK_SIZE: "256G"
  ```
  
> [!TIP]
> This can also be used to resize the existing disk to a larger capacity without any data loss. However you will need to [manually extend the disk partition](https://learn.microsoft.com/en-us/windows-server/storage/disk-management/extend-a-basic-volume?tabs=disk-management) afterwards, since the added disk space will appear as unallocated.

### How do I share files with the host?

  After installation there will be a folder called `Shared` on your desktop, which can be used to exchange files with the host machine.
  
  To select a folder on the host for this purpose, include the following bind mount in your compose file:

  ```yaml
  volumes:
    -  ./example:/shared
  ```

  Replace the example path `./example` with your desired shared folder, which then will become visible as `Shared`.

### How do I change the amount of CPU or RAM?

  By default, Windows will be allowed to use 2 CPU cores and 4 GB of RAM.

  If you want to adjust this, you can specify the desired amount using the following environment variables:

  ```yaml
  environment:
    RAM_SIZE: "8G"
    CPU_CORES: "4"
  ```

### How do I configure the username and password?

  By default, a user called `Docker` is created and its password is `admin`.

  If you want to use different credentials during installation, you can configure them in your compose file:

  ```yaml
  environment:
    USERNAME: "bill"
    PASSWORD: "gates"
  ```

### How do I select the Windows language?

  By default, the English version of Windows will be downloaded.
  
  But you can add the `LANGUAGE` environment variable to your compose file, in order to specify an alternative language to be downloaded:

  ```yaml
  environment:
    LANGUAGE: "French"
  ```
  
  You can choose between: 🇦🇪 Arabic, 🇧🇬 Bulgarian, 🇨🇳 Chinese, 🇭🇷 Croatian, 🇨🇿 Czech, 🇩🇰 Danish, 🇳🇱 Dutch, 🇬🇧 English, 🇪🇪 Estonian, 🇫🇮 Finnish, 🇫🇷 French, 🇩🇪 German, 🇬🇷 Greek, 🇮🇱 Hebrew, 🇭🇺 Hungarian, 🇮🇹 Italian, 🇯🇵 Japanese, 🇰🇷 Korean, 🇱🇻 Latvian, 🇱🇹 Lithuanian, 🇳🇴 Norwegian, 🇵🇱 Polish, 🇵🇹 Portuguese, 🇷🇴 Romanian, 🇷🇺 Russian, 🇷🇸 Serbian, 🇸🇰 Slovak, 🇸🇮 Slovenian, 🇪🇸 Spanish, 🇸🇪 Swedish, 🇹🇭 Thai, 🇹🇷 Turkish and 🇺🇦 Ukrainian.

### How do I select the keyboard layout?

  If you want to use a keyboard layout or locale that is not the default for your selected language, you can add  `KEYBOARD` and `REGION` variables like this:

  ```yaml
  environment:
    REGION: "en-US"
    KEYBOARD: "en-US"
  ```

### How do I install a custom image?

  In order to download an unsupported ISO image, specify its URL in the `VERSION` environment variable:
  
  ```yaml
  environment:
    VERSION: "https://example.com/win.iso"
  ```

  Alternatively, you can also skip the download and use a local file instead, by binding it in your compose file in this way:
  
  ```yaml
  volumes:
    - ./example.iso:/boot.iso
  ```

  Replace the example path `./example.iso` with the filename of your desired ISO file. The value of `VERSION` will be ignored in this case.

### How do I run a script after installation?

  To run your own script after installation, you can create a file called `install.bat` and place it in a folder together with any additional files it needs (software to be installed for example).
  
  Then bind that folder in your compose file like this:

  ```yaml
  volumes:
    -  ./example:/oem
  ```

  The example folder `./example` will be copied to `C:\OEM` and the containing `install.bat` will be executed during the last step of the automatic installation.

### How do I perform a manual installation?

  It's recommended to stick to the automatic installation, as it adjusts various settings to prevent common issues when running Windows inside a virtual environment.

  However, if you insist on performing the installation manually at your own risk, add the following environment variable to your compose file:

  ```yaml
  environment:
    MANUAL: "Y"
  ```

### How do I connect using RDP?

  The web-viewer is mainly meant to be used during installation, as its picture quality is low, and it has no audio or clipboard for example.

  So for a better experience you can connect using any Microsoft Remote Desktop client to the IP of the container, using the username `Docker` and password `admin`.

  There is a RDP client for [Android](https://play.google.com/store/apps/details?id=com.microsoft.rdc.androidx) available from the Play Store and one for [iOS](https://apps.apple.com/nl/app/microsoft-remote-desktop/id714464092?l=en-GB) in the Apple Store. For Linux you can use [FreeRDP](https://www.freerdp.com/) and on Windows just type `mstsc` in the search box.

### How do I assign an individual IP address to the container?

  By default, the container uses bridge networking, which shares the IP address with the host. 

  If you want to assign an individual IP address to the container, you can create a macvlan network as follows:

  ```bash
  docker network create -d macvlan \
      --subnet=192.168.0.0/24 \
      --gateway=192.168.0.1 \
      --ip-range=192.168.0.100/28 \
      -o parent=eth0 vlan
  ```
  
  Be sure to modify these values to match your local subnet. 

  Once you have created the network, change your compose file to look as follows:

  ```yaml
  services:
    windows:
      container_name: windows
      ..<snip>..
      networks:
        vlan:
          ipv4_address: 192.168.0.100

  networks:
    vlan:
      external: true
  ```
 
  An added benefit of this approach is that you won't have to perform any port mapping anymore, since all ports will be exposed by default.

> [!IMPORTANT]  
> This IP address won't be accessible from the Docker host due to the design of macvlan, which doesn't permit communication between the two. If this is a concern, you need to create a [second macvlan](https://blog.oddbit.com/post/2018-03-12-using-docker-macvlan-networks/#host-access) as a workaround.

### How can Windows acquire an IP address from my router?

  After configuring the container for [macvlan](#how-do-i-assign-an-individual-ip-address-to-the-container), it is possible for Windows to become part of your home network by requesting an IP from your router, just like a real PC.

  To enable this mode, in which the container and Windows will have separate IP addresses, add the following lines to your compose file:

  ```yaml
  environment:
    DHCP: "Y"
  devices:
    - /dev/vhost-net
  device_cgroup_rules:
    - 'c *:* rwm'
  ```

### How do I add multiple disks?

  To create additional disks, modify your compose file like this:
  
  ```yaml
  environment:
    DISK2_SIZE: "32G"
    DISK3_SIZE: "64G"
  volumes:
    - ./example2:/storage2
    - ./example3:/storage3
  ```

### How do I pass-through a disk?

  It is possible to pass-through disk devices or partitions directly by adding them to your compose file in this way:

  ```yaml
  devices:
    - /dev/sdb:/disk1
    - /dev/sdc1:/disk2
  ```

  Use `/disk1` if you want it to become your main drive (which will be formatted during installation), and use `/disk2` and higher to add them as secondary drives (which will stay untouched).

### How do I pass-through a USB device?

  To pass-through a USB device, first lookup its vendor and product id via the `lsusb` command, then add them to your compose file like this:

  ```yaml
  environment:
    ARGUMENTS: "-device usb-host,vendorid=0x1234,productid=0x1234"
  devices:
    - /dev/bus/usb
  ```

> [!WARNING]  
> Adding a USB mass storage device before Windows Setup has finished may cause it to fail. Or worse: the drive can get formatted  as the system disk, and all your data will be lost! So always keep them disconnected when launching the container for the first time.

### How do I verify if my system supports KVM?

  First check if your software is compatible using this chart:

  | **Product**  | **Linux** | **Win11** | **Win10** | **macOS** |
  |---|---|---|---|---|
  | Docker CLI        | ✅   | ✅       | ❌        | ❌ |
  | Docker Desktop    | ❌   | ✅       | ❌        | ❌ | 
  | Podman CLI        | ✅   | ✅       | ❌        | ❌ | 
  | Podman Desktop    | ✅   | ✅       | ❌        | ❌ | 

  After that you can run the following commands in Linux to check your system:

  ```bash
  sudo apt install cpu-checker
  sudo kvm-ok
  ```

  If you receive an error from `kvm-ok` indicating that KVM cannot be used, please check whether:

  - the virtualization extensions (`Intel VT-x` or `AMD SVM`) are enabled in your BIOS.

  - you enabled "nested virtualization" if you are running the container inside a virtual machine.

  - you are not using a cloud provider, as most of them do not allow nested virtualization for their VPS's.

  If you did not receive any error from `kvm-ok` but the container still complains about a missing KVM device, it could help to add `privileged: true` to your compose file (or `sudo` to your `docker` command) to rule out any permission issue.

### How do I run macOS in a container?

  You can use [dockur/macos](https://github.com/dockur/macos) for that. It shares many of the same features, except for the automatic installation.

### How do I run a Linux desktop in a container?

  You can use [qemus/qemu](https://github.com/qemus/qemu) in that case.

### Is this project legal?

  Yes, this project contains only open-source code and does not distribute any copyrighted material. Any product keys found in the code are just generic placeholders provided by Microsoft for trial purposes. So under all applicable laws, this project will be considered legal.

## Disclaimer ⚖️

*The product names, logos, brands, and other trademarks referred to within this project are the property of their respective trademark holders. This project is not affiliated, sponsored, or endorsed by Microsoft Corporation.*

[build_url]: https://github.com/dockur/windows/
[hub_url]: https://hub.docker.com/r/dockurr/windows/
[tag_url]: https://hub.docker.com/r/dockurr/windows/tags
[pkg_url]: https://github.com/dockur/windows/pkgs/container/windows

[Build]: https://github.com/dockur/windows/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/windows/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/windows.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/windows/latest?arch=amd64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Fwindows%2Fwindows.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
