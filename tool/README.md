# Release builds

## Web

Run `dart tool/build_web.dart` from the project root and publish the contents of `build/web-release`. For a site hosted under a path, pass the path with both slashes, for example `dart tool/build_web.dart /JotCalc/`.

The release bundles the full CanvasKit runtime and removes other renderer variants and debug symbols. Serve `.wasm` with `Content-Type: application/wasm`. Enable Brotli or gzip for JavaScript and WebAssembly to reduce download size.

## Android

Run `flutter build apk --release --split-per-abi --split-debug-info=build/android-symbols`. Select the device's architecture from the APKs in `build/app/outputs/flutter-apk`. Most recent Android phones use `arm64-v8a`. Android extracts the APK's compressed native libraries during installation. Keep `build/android-symbols` with the release if you need to symbolicate Dart stack traces.

Sign APKs using the app's release key before distribution. Use `flutter build appbundle --release --split-debug-info=build/android-symbols` for Google Play. [Flutter Android signing guide](https://docs.flutter.dev/deployment/android#sign-the-app)
