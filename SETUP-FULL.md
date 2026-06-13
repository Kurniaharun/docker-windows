# Setup Full — Ghost Spectre di VPS (DigitalOcean)

Panduan lengkap setup yang **sudah terbukti work**.

## Syarat VPS

- Ubuntu + KVM (`/dev/kvm` ada)
- RAM min 8 GB, disk min 40 GB
- Port terbuka: **22**, **8006** (firewall cloud)

## 1. Deploy

```bash
git clone https://github.com/Kurniaharun/docker-windows.git
cd docker-windows
docker build -t dockurr/windows:ghostspectre .
docker compose -f compose.ghostspectre.yml up -d
```

## 2. Install Ghost Spectre

1. Buka **http://IP_VPS:8006**
2. Tunggu download ISO + install manual Ghost Spectre
3. Buat akun saat setup:
   - **User:** `Administrator`
   - **Pass:** `12345678`

## 3. Post-install otomatis (Desktop)

Setelah **login pertama**, script di `oem/` otomatis jalan:

| File di Desktop | Fungsi |
|-----------------|--------|
| `Enable-RDP.bat` | Enable RDP + firewall |
| `Open-Shared.bat` | Buka folder host `\\host.lan\Data` |
| `RDP-Connect-Help.txt` | Cara connect RDP |
| `Shared` | Shortcut ke folder host |

> **Tidak perlu folder Shared manual** — bat langsung di Desktop.

Kalau belum muncul (install lama), jalankan **CMD as Admin**:

```cmd
C:\OEM\install.bat
```

## 4. Enable RDP (manual fallback)

CMD **as Administrator**:

```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
powershell -Command "Set-Service TermService -StartupType Automatic; Start-Service TermService"
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 1 /f
```

Output sukses: `The operation completed successfully` + `Updated 3 rule(s)`.

## 5. Connect RDP

**Port 3389/8007 diblok firewall DigitalOcean dari luar.** Pakai SSH tunnel:

### Windows PC

```powershell
ssh -N -L 13389:127.0.0.1:8007 root@IP_VPS
```

Atau jalankan `rdp-tunnel.bat` (edit IP dulu).

### mstsc

| | |
|---|---|
| Computer | `localhost:13389` |
| User | `Administrator` |
| Pass | `12345678` |

## 6. Direct RDP (opsional)

Buka port **8007/TCP** di DigitalOcean Firewall, lalu:

```
IP_VPS:8007
```

## Struktur OEM (installer)

```
oem/
  install.bat           # First logon: copy bat ke Desktop + enable RDP
  SetupComplete.cmd     # RunOnce hook saat Windows Setup selesai
  _enable_rdp_core.bat  # Core RDP enable commands
  Enable-RDP.bat        # Manual re-run
  Open-Shared.bat       # Buka \\host.lan\Data
  RDP-Connect-Help.txt  # Panduan connect
```

Mount di compose: `./oem:/oem`

## Version keys

| VERSION | ISO |
|---------|-----|
| `gs11` | Ghost Spectre Win11 |
| `gs10` | Ghost Spectre Win10 |

## Windows resmi (bukan Ghost)

Auto user **`KurrXd`** / **`admin`** via autounattend.

---

## Golden Image — Deploy auto tanpa setup ulang

Setelah Windows + app + setting selesai, **backup `data.img`**:

```bash
./scripts/backup-golden.sh
# Output: golden/windows-golden.tar.gz
```

**Next deploy** (VPS baru / reinstall) — langsung boot, **zero setup**:

```bash
# Upload golden/windows-golden.tar.gz ke VPS
./scripts/restore-golden.sh
docker compose -f compose.ghostspectre.yml up -d
```

Dari PC Windows:
- **Backup:** double-click `backup-golden.bat`
- **Restore:** double-click `restore-golden.bat`

Yang ter-restore: user, RDP, app, setting — semua dari `data.img` kamu.
