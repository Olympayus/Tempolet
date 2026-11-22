# tempolet

A new Flutter project.

## Golden screenshot acceptance

Two separate golden harnesses exist, with different rendering conditions:

- **Gallery** (`test/gallery/gallery_test.dart`, untracked by convention): the
  app's own widgets with the real Inter / NotoSansSC / Material Icons / Lucide
  fonts loaded through `FontLoader`, at a fixed 1280×820 logical surface,
  DPR 1.0, locale `en_US` and `today = 2026-11-16`.
- **Tracked month-view golden** (`test/features/month_view_golden_test.dart` →
  `test/features/goldens/month_view.png`): a bare `MonthView` at a fixed
  900×700 logical surface, DPR 1.0, locale `en`, `today = 2026-11-11`, and the
  default test font (Ahem — no `FontLoader`).

Record and verify the baselines on a **Windows** machine only — the PNG files
are platform-specific in v0.1.3:

```powershell
# Record every baseline (see the clean-tree rule below)
flutter test --update-goldens test/gallery/gallery_test.dart
flutter test --update-goldens test/features/month_view_golden_test.dart

# Verify
flutter test test/gallery/gallery_test.dart
flutter test test/features/month_view_golden_test.dart
flutter test
```

- **Threshold:** 0 pixel difference is the pass bar on the machine that
  recorded the baselines. The repo uses the default exact `LocalFileComparator`
  with no custom comparator, so the 0.01 (1%) per-pixel tolerance is a
  manual-review allowance for cross-machine differences (AA / font rasterizer),
  not an automatic pass.
- **Clean-tree rule:** record only when `git status --porcelain` shows no
  tracked changes. Untracked `test/gallery/` and `test/features/failures/` are
  expected; `.superpowers/` is gitignored and never committed. Record the
  `git rev-parse HEAD` SHA next to the recording so the baseline can be traced
  back to a commit; the v0.1.3 baselines were recorded on
  `5bb6221b1e094dc7543a3bd71c8efb02540ba8c8`.
- `test/gallery/` stays untracked by convention with the mobile session; the
  tracked baseline is `test/features/goldens/month_view.png`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Android build (v0.1.5)

```bash
flutter build apk --release      # universal APK for direct install
```

- `applicationId`: `com.tempolet.tempolet`; version `0.1.5+6`; app label `Tempolet`.
- Signing: provide `android/key.properties` + keystore locally (gitignored);
  without it the release APK uses debug signing and is smoke-test only.
- Runtime permissions: Android 13+ asks for notifications the first time an
  item with a reminder is saved; Android 12+ schedules exact alarms, falling
  back to inexact (possibly delayed) when the special permission is missing.
  Settings shows a state row with a jump to the system settings.
- Reminders are restored after reboot and re-planned on time/timezone changes;
  the first run may download the sqlite3 Android prebuilt binary, so network
  or a proxy is required at build time.
