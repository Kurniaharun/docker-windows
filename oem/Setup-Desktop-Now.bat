@echo off
set DESKTOP=%USERPROFILE%\Desktop
copy /Y "%~dp0Enable-RDP.bat" "%DESKTOP%\" >nul 2>&1
copy /Y "%~dp0Open-Shared.bat" "%DESKTOP%\" >nul 2>&1
copy /Y "%~dp0RDP-Connect-Help.txt" "%DESKTOP%\" >nul 2>&1
call "%~dp0_enable_rdp_core.bat"
mklink /d "%DESKTOP%\Shared" \\host.lan\Data 2>nul
echo Done - check Desktop
pause
