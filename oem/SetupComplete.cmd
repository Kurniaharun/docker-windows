@echo off
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v DockerPostInstall /t REG_SZ /d "cmd /C C:\OEM\install.bat" /f
exit /b 0
