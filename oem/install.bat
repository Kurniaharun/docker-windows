@echo off
setlocal
set "DESKTOP=%USERPROFILE%\Desktop"
set "OEM=C:\OEM"

if not exist "%DESKTOP%" mkdir "%DESKTOP%"

copy /Y "%OEM%\Enable-RDP.bat" "%DESKTOP%\" >nul 2>&1
copy /Y "%OEM%\Open-Shared.bat" "%DESKTOP%\" >nul 2>&1
copy /Y "%OEM%\RDP-Connect-Help.txt" "%DESKTOP%\" >nul 2>&1

call "%OEM%\_enable_rdp_core.bat"

if not exist "%DESKTOP%\Shared" (
  mklink /d "%DESKTOP%\Shared" \\host.lan\Data >nul 2>&1
)

if exist "%~f0" del /f /q "%~f0" >nul 2>&1
exit /b 0
