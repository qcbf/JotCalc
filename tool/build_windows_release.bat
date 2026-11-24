@echo off
setlocal EnableExtensions
set "PS_EXE=powershell"
where pwsh >nul 2>&1
if not errorlevel 1 set "PS_EXE=pwsh"

if defined FLUTTER_ROOT set "PATH=%FLUTTER_ROOT%\bin;%PATH%"
if defined FLUTTER_BIN set "PATH=%FLUTTER_BIN%;%PATH%"
if not defined PUB_CACHE if exist "%TEMP%\jotcalc-pub-cache" set "PUB_CACHE=%TEMP%\jotcalc-pub-cache"
where flutter >nul 2>&1
if errorlevel 1 if exist "%TEMP%\jotcalc-flutter-3.50.1\bin\flutter.bat" set "PATH=%TEMP%\jotcalc-flutter-3.50.1\bin;%PATH%"
where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter was not found. Set FLUTTER_ROOT or add Flutter to PATH.
  exit /b 1
)

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows_release.ps1"
exit /b %ERRORLEVEL%
