@echo off
echo Enabling Remote Desktop...
call "%~dp0_enable_rdp_core.bat"
echo.
echo RDP enabled.
echo Connect via SSH tunnel: localhost:13389
echo User: Administrator  Pass: 12345678
pause
