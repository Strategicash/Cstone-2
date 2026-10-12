# AGENTS.md

Flutter mobile app ("FitX Training Club"). Single-entry, no monorepo, no CI.

## Commands
- `flutter analyze` — lint + static analysis (rules from `package:flutter_lints/flutter.yaml`).
- `flutter test` — runs widget tests.

## Gotchas
- **`test/widget_test.dart` is stale and won't compile.** It still references the deleted `MyApp` counter demo, but the app now defines `FitXApp`, `LoginScreen`, `HomeScreen`. The default smoke test is broken; `flutter test` fails on compile. Fix/remove it before relying on `flutter test`. There is no passing test suite.
- `lib/` is modular: `main.dart` is minimal (entry + `FitXApp`), `screens/` = `login_screen.dart` + `home_screen.dart`, `widgets/` = UI components (incl. `app_drawer.dart`), `models/user_metrics.dart` = data, `theme/app_theme.dart` = palette + themes. Keep new screens/widgets in these folders; `UserMetrics.fromLoginPayload` is the single defensive parser — route new backend data through it.
- `AppTheme.mode` is a global `ValueNotifier<ThemeMode>`; the sidebar's Dark Mode switch sets it and `FitXApp` listens via `ValueListenableBuilder`. Do not add per-screen theme state.
- `HomeScreen` is responsive: narrow screens get a Scaffold drawer, ≥900px width gets a fixed 300px side panel (`AppDrawer`, `automaticallyClose: false`). Workouts/Progress/Body Metrics/My Coach/Profile are placeholders — extend `_buildContent` in `home_screen.dart`.
- Login posts JSON to a **hardcoded Android-emulator backend URL**: `http://192.168.0.131/Capstone Project1/api_login.php` (`login_screen.dart`). `192.168.0.131` is the emulator's alias for host localhost — it does not work on physical devices or iOS simulator. The path contains a space and is URL-encoded; don't "fix" the spacing without updating the server route. The full login response JSON is passed to `HomeScreen(loginData:)`.
- Networking uses the `http` package (only third-party runtime dep besides `cupertino_icons`).
- Android network calls to plain HTTP (cleartext) are affected by Android cleartext-traffic policy; app talks to an unencrypted dev backend.

## Analysis
- `analysis_options.yaml` excludes platform dirs (`android/`, `ios/`, `web/`, etc.) and `build/**` from analysis — only `lib/` and `test/` are analyzed.
