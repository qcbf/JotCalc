@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"

call "%SCRIPT_DIR%build_web_release.bat"
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%build_android_release.bat"
if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%build_windows_release.bat"
if errorlevel 1 exit /b 1

echo Web, Android, and Windows release assets are ready.
exit /b 0
