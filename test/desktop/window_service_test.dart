import 'package:flutter/widgets.dart' show Rect, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/desktop/window_service.dart';

void main() {
  test('default window size is 1280x820', () {
    expect(defaultWindowSize, const Size(1280, 820));
  });

  test('minimum window size is 960x600', () {
    expect(minimumWindowSize, const Size(960, 600));
  });

  group('window bounds persistence', () {
    test('encode and decode round-trip', () {
      const bounds = Rect.fromLTWH(120, 80, 1280, 820);
      final encoded = encodeWindowBounds(bounds);

      expect(decodeWindowBounds(encoded), bounds);
    });

    test('decode rejects malformed or non-finite data', () {
      expect(decodeWindowBounds(null), isNull);
      expect(decodeWindowBounds(''), isNull);
      expect(decodeWindowBounds('1,2,3'), isNull);
      expect(decodeWindowBounds('1,2,3,4,5'), isNull);
      expect(decodeWindowBounds('a,2,3,4'), isNull);
      expect(decodeWindowBounds('0,0,Infinity,820'), isNull);
      expect(decodeWindowBounds('0,0,NaN,820'), isNull);
    });

    test('restore accepts bounds at least the minimum size', () {
      const saved = Rect.fromLTWH(100, 50, 1280, 820);

      expect(restoreWindowBounds(saved), saved);
    });

    test('restore rejects bounds below the minimum size', () {
      expect(
        restoreWindowBounds(const Rect.fromLTWH(100, 50, 800, 500)),
        isNull,
      );
      expect(
        restoreWindowBounds(const Rect.fromLTWH(100, 50, 1280, 599)),
        isNull,
      );
    });

    test('restore rejects non-finite bounds', () {
      expect(
        restoreWindowBounds(
          const Rect.fromLTWH(double.infinity, 0, 1280, 820),
        ),
        isNull,
      );
    });

    test('restore rejects bounds entirely off the virtual desktop', () {
      expect(
        restoreWindowBounds(const Rect.fromLTWH(50000, 50000, 1280, 820)),
        isNull,
      );
      expect(
        restoreWindowBounds(const Rect.fromLTWH(-50000, -50000, 1280, 820)),
        isNull,
      );
    });

    test('restore clamps partially off-screen bounds back onto the desktop',
        () {
      final restored = restoreWindowBounds(
        const Rect.fromLTWH(16000, -16000, 1280, 820),
      );

      expect(
        restored,
        Rect.fromLTWH(
          virtualDesktopEnvelope.right - 1280,
          -16000,
          1280,
          820,
        ),
      );
    });

    test('restore falls back to null for missing bounds', () {
      expect(restoreWindowBounds(null), isNull);
    });
  });
}
