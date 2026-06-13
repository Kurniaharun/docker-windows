# Restore Golden Image — Deploy Tanpa Setup

Panduan restore Windows dari backup `windows-golden.tar.gz`.
**100% dari SSH — tidak perlu masuk Windows.**

---

## Link Golden Image

```
https://archive.org/download/windows-golden.tar/windows-golden.tar.gz
```

Size: ~5.5 GB

---

## Syarat VPS

- Ubuntu + KVM (`/dev/kvm` harus ada)
- RAM min 8 GB, disk min 40 GB
- Docker terinstall

```bash
ls -l /dev/kvm
apt update && apt install -y docker.io docker-compose-plugin git
```

---

## Restore — VPS Baru (Full Auto)

### 1. Clone repo

```bash
ssh root@IP_VPS
git clone https://github.com/Kurniaharun/docker-windows.git
cd docker-windows
docker build -t dockurr/windows:ghostspectre .
```

### 2. Download golden image

```bash
mkdir -p golden

# Ganti LINK di bawah dengan link archive.org kamu
wget -O golden/windows-golden.tar.gz "https://archive.org/download/windows-golden.tar/windows-golden.tar.gz"
```

Atau upload dari PC:

```powershell
scp golden\windows-golden.tar.gz root@IP_VPS:/root/docker-windows/golden/
```

### 3. Restore + start

```bash
chmod +x scripts/*.sh
./scripts/restore-golden.sh
```

Windows langsung boot — **tanpa install, tanpa setup user, tanpa enable RDP.**

### 4. Connect RDP (opsional, kalau mau pakai)

Firewall cloud (DigitalOcean) blok port RDP direct. Pakai SSH tunnel:

```powershell
ssh -N -L 13389:127.0.0.1:8007 root@IP_VPS
```

mstsc → `localhost:13389`

| | |
|---|---|
| User | `Administrator` |
| Pass | `12345678` |

Web viewer: `http://IP_VPS:8006`

---

## Restore — Dari PC Windows

1. Edit IP di `restore-golden.bat`
2. Taruh `windows-golden.tar.gz` di folder `golden/`
3. Double-click `restore-golden.bat`

---

## Yang Sudah Termasuk di Golden Image

- Ghost Spectre Windows (sudah terinstall)
- User `Administrator` / `12345678`
- RDP enabled
- App & setting yang sudah dikonfigurasi saat backup

---

## Backup Ulang (setelah update Windows)

```bash
ssh root@IP_VPS
cd /root/docker-windows
./scripts/backup-golden.sh
```

Atau double-click `backup-golden.bat` dari PC.

Output: `golden/windows-golden.tar.gz` → upload ke archive.org → update link di atas.

---

## Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `/dev/kvm` tidak ada | VPS tidak support nested virt — ganti provider |
| Container restart loop | `docker compose logs -f` — cek disk space |
| RDP tidak connect | Pakai SSH tunnel port 8007, bukan 3389 direct |
| `data.img` corrupt | Download ulang golden image |

---

## File Penting

| File | Fungsi |
|------|--------|
| `scripts/restore-golden.sh` | Restore di VPS |
| `scripts/backup-golden.sh` | Backup golden image |
| `restore-golden.bat` | Restore dari PC |
| `backup-golden.bat` | Backup + download ke PC |
| `compose.ghostspectre.yml` | Config container |
| `rdp-tunnel.bat` | SSH tunnel RDP |

Repo: https://github.com/Kurniaharun/docker-windows
