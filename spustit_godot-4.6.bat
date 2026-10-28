@echo off
chcp 65001 >nul
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
  py -3 spustit.py docs-4.6
  goto :konec
)
where python >nul 2>nul
if %errorlevel%==0 (
  python spustit.py docs-4.6
  goto :konec
)
echo.
echo Pro spusteni hry je potreba Python (zdarma): https://www.python.org/downloads/
echo Pri instalaci zaskrtni "Add python.exe to PATH". Pak spust tento soubor znovu.
echo.
pause
:konec
