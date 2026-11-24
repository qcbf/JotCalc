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
where dart >nul 2>&1
if errorlevel 1 (
  echo Dart was not found. Use the Dart bundled with Flutter.
  popd
  exit /b 1
)

call flutter pub get
if errorlevel 1 goto :failed
call dart tool\build_web.dart
if errorlevel 1 goto :failed

set "WEB_ZIP=%PROJECT_ROOT%\build\jotcalc-web-release.zip"
%PS_EXE% -NoProfile -ExecutionPolicy Bypass -Command ^
  "$source = Join-Path (Get-Location) 'build\web-release'; $destination = Join-Path (Get-Location) 'build\jotcalc-web-release.zip'; if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }; Compress-Archive -Path (Join-Path $source '*') -DestinationPath $destination -CompressionLevel Optimal"
if errorlevel 1 goto :failed
%PS_EXE% -NoProfile -ExecutionPolicy Bypass -Command ^
  "$file = Get-Item -LiteralPath '%WEB_ZIP%'; $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName -ErrorAction Stop).Hash; Set-Content -LiteralPath ($file.FullName + '.sha256') -Value ($hash + '  ' + $file.Name) -Encoding ascii"
if errorlevel 1 goto :failed
if not exist "%WEB_ZIP%.sha256" goto :failed

echo Web release created at build\jotcalc-web-release.zip
echo Checksum created at build\jotcalc-web-release.zip.sha256
popd
exit /b 0

:failed
echo Web release build failed.
popd
exit /b 1
