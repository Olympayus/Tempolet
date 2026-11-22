import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/app_segmented.dart';
import 'package:tempolet/core/ui/touch_target.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/shell/phone_dock.dart';

/// Boots the real app on a phone/tablet-sized view.
///
/// The local copy keeps this file independent from `app_navigation_test.dart`
/// (per the task brief); [bottomInset] emulates the Android gesture bar.
Future<void> pumpApp(
  WidgetTester tester, {
  Size? size,
  double bottomInset = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  if (bottomInset > 0) {
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPadding);
  }
  addTearDown(() => debugLayoutOverride = null);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        eventsInRangeProvider.overrideWith(
          (ref, arg) => Stream.value(const <Event>[]),
        ),
        holidaysProvider.overrideWith((ref) => Stream.value(const <Holiday>[])),
      ],
      child: const TempoletApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('dock clearance includes the gesture bar', () {
    expect(phoneDockClearance(24), 48 + 12 + 12 + 24);
    expect(phoneDockBottomOffset(24), 36);
  });

  testWidgets('TouchTarget floors the hit box at 44 and centers its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: TouchTarget(
            child: SizedBox(key: ValueKey('tiny-child'), width: 20, height: 20),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TouchTarget)), const Size(44, 44));
    expect(
      tester.getCenter(find.byKey(const ValueKey('tiny-child'))),
      tester.getCenter(find.byType(TouchTarget)),
    );
  });

  testWidgets('TouchTarget lets a wider child keep its width', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: TouchTarget(child: SizedBox(width: 120, height: 20)),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TouchTarget)), const Size(120, 44));
  });

  testWidgets('phone shell lifts the dock above the bottom inset', (
    tester,
  ) async {
    debugLayoutOverride = AppLayout.phone;
    await pumpApp(tester, size: const Size(375, 812), bottomInset: 24);

    final dock = tester.getBottomLeft(find.byKey(const ValueKey('phone-dock')));
    expect(dock.dy, 812 - 36);
  });

  testWidgets('tablet rail keeps 27 visual but 44 hit target', (tester) async {
    debugLayoutOverride = AppLayout.tablet;
    await pumpApp(tester, size: const Size(1280, 800));

    expect(
      tester.getSize(find.byKey(const ValueKey('rail-calendar-hit'))),
      const Size(44, 44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('rail-calendar'))),
      const Size(27, 27),
    );
  });

  testWidgets('tablet segment is 36 high on the large tier with 44 vertical '
      'hit', (tester) async {
    debugLayoutOverride = AppLayout.tablet;
    // Shortest side >= 1000 so LayoutMetrics resolves the large tablet tier
    // (§8.7); the brief's 1280×800 example would be the 700–999 tier (34).
    await pumpApp(tester, size: const Size(1280, 1000));

    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-view-segmented')))
          .height,
      36,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('calendar-view-segmented-hit')))
          .height,
      44,
    );
  });

  testWidgets('segment taps land in the 44 band outside the visual track', (
    tester,
  ) async {
    debugLayoutOverride = AppLayout.tablet;
    addTearDown(() => debugLayoutOverride = null);
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var picked = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: AppSegmented<String>(
                visualKey: const ValueKey('segmented-visual'),
                hitKey: const ValueKey('segmented-hit'),
                values: const ['a', 'b'],
                labelFor: (value) => Text(value),
                selected: picked,
                onChanged: (value) => picked = value,
              ),
            ),
          ),
        ),
      ),
    );

    final hit = tester.getRect(find.byKey(const ValueKey('segmented-hit')));
    final visual = tester.getRect(
      find.byKey(const ValueKey('segmented-visual')),
    );
    expect(hit.height, 44);
    expect(visual.height, 36);
    expect(visual.top - hit.top, 4);

    // 2px above the visual track, inside the second item's 44-high band.
    await tester.tapAt(
      Offset(visual.left + visual.width * 0.75, visual.top - 2),
    );
    expect(picked, 'b');

    // 2px below the visual track, inside the first item's band.
    await tester.tapAt(
      Offset(visual.left + visual.width * 0.25, visual.bottom + 2),
    );
    expect(picked, 'a');
  });
}
