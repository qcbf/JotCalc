# Release builds

## Automated release

Run `pwsh -File tool/release.ps1` from a clean `main` checkout. The script increments
the patch version and Android build number, commits the new version, creates an
annotated `vX.Y.Z` tag, and pushes the branch and tag. The tag starts the GitHub
Actions workflow in `.github/workflows/release.yml`.

Pass `-Version 1.0.0` when a major or minor release is needed. Use
`-WhatIf` to inspect the next version without changing the repository.

The workflow publishes a Web ZIP, arm64-v8a, armeabi-v7a, and x86_64 APKs, plus
SHA-256 checksums, to the GitHub Release. It uses the project's default Android
release signing behavior unless the repository has these Actions secrets
configured: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD`.

## Windows batch scripts

From the project root, these commands create local release files:

```bat
tool\build_web_release.bat
tool\build_android_release.bat
tool\build_release.bat
```

The combined script writes the Web ZIP to `build\jotcalc-web-release.zip` and
the APKs and checksums to `build\release-assets`. Set `FLUTTER_ROOT` when Flutter
is not on PATH, for example `set FLUTTER_ROOT=C:\src\flutter`.

To create the version commit, tag, and GitHub Release build, run:

```bat
tool\publish_release.bat
tool\publish_release.bat 1.0.0
tool\publish_release.bat -WhatIf
```

## Web

Run `dart tool/build_web.dart` from the project root and publish the contents of `build/web-release`. For a site hosted under a path, pass the path with both slashes, for example `dart tool/build_web.dart /JotCalc/`.

The release bundles the full CanvasKit runtime and removes other renderer variants and debug symbols. Serve `.wasm` with `Content-Type: application/wasm`. Enable Brotli or gzip for JavaScript and WebAssembly to reduce download size.

## Android

Run `flutter build apk --release --split-per-abi --split-debug-info=build/android-symbols`. Select the device's architecture from the APKs in `build/app/outputs/flutter-apk`. Most recent Android phones use `arm64-v8a`. Android extracts the APK's compressed native libraries during installation. Keep `build/android-symbols` with the release if you need to symbolicate Dart stack traces.

Sign APKs using the app's release key before distribution. Use `flutter build appbundle --release --split-debug-info=build/android-symbols` for Google Play. [Flutter Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app)
