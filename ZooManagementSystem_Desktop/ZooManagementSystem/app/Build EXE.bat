@echo off
title Build ZooManagementSystem.exe
cd /d "%~dp0"
echo Installing build tools...
py -m pip install --upgrade pyinstaller pyodbc
echo Building the .exe (takes 1-2 minutes)...
py -m PyInstaller --noconfirm --onefile --windowed --name ZooManagementSystem main.py
copy /Y zoo_settings.ini dist\zoo_settings.ini >nul
echo.
echo Done! Your app is in the "dist" folder:
echo   dist\ZooManagementSystem.exe
echo   dist\zoo_settings.ini   (keep it next to the .exe)
pause
