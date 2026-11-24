# Release builds

## Automated release

Run `pwsh -File tool/release.ps1` from a clean `main` checkout. The script increments
the patch version and Android build number, commits the new version, creates an
annotated `vX.Y.Z` tag, and pushes the branch and tag. The tag starts the GitHub
Actions workflow in `.github/workflows/release.yml`.

Pass `-Version 1.1.0` when a specific version is needed. Use
`-WhatIf` to inspect the next version without changing the repository.

The workflow publishes a Web ZIP, arm64-v8a, armeabi-v7a, and x86_64 APKs, a
Windows x64 ZIP, and SHA-256 checksums to the GitHub Release. The Windows ZIP
is built for tags containing the Windows runner. For Android releases that users can
upgrade in place, configure `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD` as Actions secrets and
use the same signing key for each version. The workflow uses its runner's debug
key when these secrets are empty.

To retry publication of an existing tag, open the Release workflow in GitHub
Actions, select **Run workflow** on `main`, and enter the tag.

## Windows batch scripts

| Script | Output |
| --- | --- |
| `tool\build_web_release.bat` | Web ZIP and checksum in `build` |
| `tool\build_android_release.bat` | Three APKs and checksums in `build\release-assets` |
| `tool\build_windows_release.bat` | Windows x64 ZIP and checksum in `build` |
| `tool\build_release.bat` | Web, Android, and Windows files |

Double-click a batch script or run it from the project root. Set `FLUTTER_ROOT`
to your Flutter SDK folder when needed. For example, run
`set FLUTTER_ROOT=C:\src\flutter` in Command Prompt.

`tool\publish_release.bat` creates the version commit and tag, then pushes them
to start the GitHub Release workflow. The `-WhatIf` option previews the version.

```bat
tool\publish_release.bat
tool\publish_release.bat 1.1.0
tool\publish_release.bat -WhatIf
```

## Web

Run `dart tool/build_web.dart` from the project root and publish the contents of `build/web-release`. For a site hosted under a path, pass the path with both slashes, for example `dart tool/build_web.dart /JotCalc/`.

To host the ZIP from the Windows build, extract it and upload `index.html`
and the accompanying files and directories to the web server's site root.

The release bundles the full CanvasKit runtime and removes other renderer variants and debug symbols. Serve `.wasm` with `Content-Type: application/wasm`. Enable Brotli or gzip for JavaScript and WebAssembly to reduce download size.

## Android

For local release signing, put the keystore settings in `local.json` at the project root.

```json
{
  "Keystore": {
    "Path": "f.keystore",
    "AliasName": "",
    "Password": "",
    "KeyPassword": ""
  }
}
```

`Path` defaults to `f.keystore`. Relative paths resolve from the directory containing
`local.json`. Fill in `AliasName` and the keystore `Password`. Leave `KeyPassword`
empty if the key uses the same password. `android/key.properties` takes precedence
when present.

Run `flutter build apk --release --split-per-abi --split-debug-info=build/android-symbols`. Select the device's architecture from the APKs in `build/app/outputs/flutter-apk`. Most recent Android phones use `arm64-v8a`. Android extracts the APK's compressed native libraries during installation. Keep `build/android-symbols` with the release if you need to symbolicate Dart stack traces.

Sign APKs using the app's release key before distribution. Use `flutter build appbundle --release --split-debug-info=build/android-symbols` for Google Play. [Flutter Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app)

## Windows x64

Run `tool\build_windows_release.bat` on Windows x64 with Flutter and Visual
Studio's Desktop development with C++ workload. The script writes
`build/jotcalc-windows-x64.zip` and its SHA-256 checksum.

To run JotCalc on Windows 10 or 11 x64, extract the entire ZIP and open
`JotCalc.exe`. The ZIP includes the DLLs, Visual C++ runtime, and data folder
used by the executable.
