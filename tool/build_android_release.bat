@echo off
setlocal EnableExtensions
set "PROJECT_ROOT=%~dp0.."
pushd "%PROJECT_ROOT%" || exit /b 1
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
  popd
  exit /b 1
)

call flutter pub get
if errorlevel 1 goto :failed
call flutter build apk --release --split-per-abi --split-debug-info=build\android-symbols
if errorlevel 1 goto :failed

set "APK_DIR=%PROJECT_ROOT%\build\app\outputs\flutter-apk"
set "ASSET_DIR=%PROJECT_ROOT%\build\release-assets"
if not exist "%ASSET_DIR%" mkdir "%ASSET_DIR%"
copy /Y "%APK_DIR%\app-arm64-v8a-release.apk" "%ASSET_DIR%\jotcalc-arm64-v8a.apk" >nul
if errorlevel 1 goto :failed
copy /Y "%APK_DIR%\app-armeabi-v7a-release.apk" "%ASSET_DIR%\jotcalc-armeabi-v7a.apk" >nul
if errorlevel 1 goto :failed
copy /Y "%APK_DIR%\app-x86_64-release.apk" "%ASSET_DIR%\jotcalc-x86_64.apk" >nul
if errorlevel 1 goto :failed

%PS_EXE% -NoProfile -ExecutionPolicy Bypass -Command ^
  "$names = @('jotcalc-arm64-v8a.apk', 'jotcalc-armeabi-v7a.apk', 'jotcalc-x86_64.apk'); $files = foreach ($name in $names) { Get-Item -LiteralPath (Join-Path '%ASSET_DIR%' $name) -ErrorAction Stop }; $lines = foreach ($file in $files) { $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName -ErrorAction Stop).Hash; $hash + '  ' + $file.Name }; Set-Content -LiteralPath (Join-Path '%ASSET_DIR%' 'SHA256SUMS.txt') -Value $lines -Encoding ascii"
if errorlevel 1 goto :failed
if not exist "%ASSET_DIR%\SHA256SUMS.txt" goto :failed

echo Android release APKs created at build\release-assets
echo Checksum created at build\release-assets\SHA256SUMS.txt
popd
exit /b 0

:failed
echo Android release build failed.
popd
exit /b 1
