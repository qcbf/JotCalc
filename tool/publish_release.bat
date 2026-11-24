@echo off
setlocal EnableExtensions
set "PROJECT_ROOT=%~dp0.."
pushd "%PROJECT_ROOT%" || exit /b 1

where pwsh >nul 2>&1
if errorlevel 1 (
  echo PowerShell 7 was not found. Install pwsh to publish a tagged release.
  popd
  exit /b 1
)

if /I "%~1"=="-WhatIf" (
  call pwsh -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\tool\release.ps1" -WhatIf
) else if "%~1"=="" (
  call pwsh -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\tool\release.ps1"
) else (
  call pwsh -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\tool\release.ps1" -Version "%~1"
)
set "RESULT=%ERRORLEVEL%"
popd
exit /b %RESULT%
