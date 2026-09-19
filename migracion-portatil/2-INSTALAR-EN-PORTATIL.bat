@echo off
setlocal
title Migajaland - Instalar copia en el portatil
set "MIGRA_PS1=%~dp0Instalar-Copia-Migajaland.ps1"
if not exist "%MIGRA_PS1%" (
  echo ERROR: No se encontro Instalar-Copia-Migajaland.ps1 junto a este archivo.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%MIGRA_PS1%" -ArchivePath "%~1"
set "MIGRA_EXIT=%ERRORLEVEL%"
echo.
if not "%MIGRA_EXIT%"=="0" echo La instalacion no se completo. Lee el mensaje anterior.
pause
exit /b %MIGRA_EXIT%

