@echo off
REM Restore golden image ke VPS — Windows langsung jalan tanpa install
set VPS=root@139.59.39.211
set REPO=/root/docker-windows

if not exist "golden\windows-golden.tar.gz" (
  echo ERROR: golden\windows-golden.tar.gz tidak ditemukan
  pause
  exit /b 1
)

echo === Upload golden image ke VPS ===
ssh %VPS% "mkdir -p %REPO%/golden"
scp golden\windows-golden.tar.gz %VPS%:%REPO%/golden/

echo === Restore + start Windows ===
ssh %VPS% "cd %REPO% && git pull origin master 2>/dev/null; chmod +x scripts/*.sh; ./scripts/restore-golden.sh"

echo.
echo Selesai! Windows boot langsung dari golden image.
pause
