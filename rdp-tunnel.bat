@echo off
set VPS_IP=139.59.39.211
echo SSH tunnel RDP ke VPS Windows...
echo.
echo 1. Biarkan jendela ini terbuka
echo 2. mstsc -^> localhost:13389
echo 3. User: Administrator  Pass: 12345678
echo.
ssh -N -L 13389:127.0.0.1:8007 root@%VPS_IP%
