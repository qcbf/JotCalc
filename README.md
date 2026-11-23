# JotCalc
A tape-style calculator for Android and the web with a persistent history sidebar, built for quick, throwaway bookkeeping.

## Development

Use Flutter 3.50.1 and run `flutter pub get`. Run `flutter test` for the calculation and interaction tests.

- **Android** requires JDK 17 or newer and the Android SDK. Run `flutter run` with an Android device connected. Use `flutter build apk --debug` to build an installable debug APK.
- **Web** runs locally with `flutter run -d chrome` or `flutter run -d edge`. Use `flutter build web --no-web-resources-cdn` to generate a static site in `build/web` with the Flutter engine bundled. History and layout settings are stored in the browser for that site's origin. Clipboard access requires HTTPS or a local development address.

Tap the expression to edit at the cursor. The built-in keypad previews the result while you type. Press `=` to confirm, or long-press the displayed result to copy it. **Save to history only when holding =** makes a short press confirm the result and a long press save it to history.

Choose **简体中文** or **English** under **Settings → Language**. The change applies immediately and is saved for the next launch.
