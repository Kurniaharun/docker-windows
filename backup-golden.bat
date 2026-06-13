@echo off
REM Backup golden image dari VPS Windows yang sudah disetup
REM Jalankan di PC: upload script ini ke VPS lalu chmod +x

set VPS=root@139.59.39.211
set REPO=/root/docker-windows

echo === Backup Windows golden image di VPS ===
ssh %VPS% "cd %REPO% && git pull origin master 2>/dev/null; chmod +x scripts/*.sh; ./scripts/backup-golden.sh"
echo.
echo === Download golden image ke PC ===
mkdir golden 2>nul
scp %VPS%:%REPO%/golden/windows-golden.tar.gz golden\
echo.
echo Selesai! File: golden\windows-golden.tar.gz
echo Simpan file ini — dipakai untuk deploy auto tanpa setup.
pause
