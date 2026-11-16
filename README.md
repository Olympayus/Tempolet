# tempolet

A new Flutter project.

## Golden screenshot acceptance

The screenshot gallery and the month-view golden are rendered by the app's own
widgets with the real Inter / NotoSansSC / Material Icons / Lucide fonts, at a
fixed 1280×820 logical surface, DPR 1.0, locale `en_US` and
`today = 2026-11-16` (see `test/gallery/gallery_test.dart` and
`test/features/month_view_golden_test.dart`).

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

- **Threshold:** 0 pixel difference when re-running on the machine that
  recorded the baselines; a 0.01 (1%) per-pixel tolerance applies only when a
  baseline is compared across machines (AA / font rasterizer differences).
- **Clean-tree rule:** record only when `git status --porcelain` shows no
  tracked changes. Untracked `test/gallery/`, `test/features/failures/` and
  `.superpowers/` are expected and fine. Record the `git rev-parse HEAD` SHA
  next to the recording so the baseline can be traced back to a commit; the
  v0.1.3 baselines were recorded on
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
