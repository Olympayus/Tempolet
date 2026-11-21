import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/gesture_edges.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/day_view.dart';
import 'package:tempolet/features/calendar/week_view.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = AppLayout.tablet;
  addTearDown(() => debugLayoutOverride = null);
}

void main() {
  test('edge swipe ignores the 20dp system back zone', () {
    expect(isEdgeSwipe(5, 1280), isTrue);
    expect(isEdgeSwipe(1275, 1280), isTrue);
    expect(isEdgeSwipe(640, 1280), isFalse);
  });

  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 11, 16)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed({
    required String title,
    required DateTime day,
    String kind = 'reminder',
    int startMinute = 540,
    int? endMinute,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: day,
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: 0,
    );
  }

  Future<void> pumpWeek(
    WidgetTester tester,
    DateTime day, {
    Size size = const Size(1280, 800),
  }) async {
    _useSize(tester, size);
    container.read(selectedDayProvider.notifier).select(day);
    await tester.pumpWidget(_app(container, const WeekView()));
    await _settle(tester);
  }

  Future<void> pumpDay(
    WidgetTester tester,
    DateTime day, {
    Size size = const Size(1280, 800),
  }) async {
    _useSize(tester, size);
    container.read(selectedDayProvider.notifier).select(day);
    await tester.pumpWidget(_app(container, const DayView()));
    await _settle(tester);
  }

  testWidgets('tablet week swipes one week; edge swipe does not', (
    tester,
  ) async {
    await pumpWeek(tester, DateTime(2026, 11, 20));

    await tester.dragFrom(const Offset(640, 400), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 27));

    await tester.dragFrom(const Offset(4, 400), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 27));
  });

  testWidgets('tablet day swipes one day', (tester) async {
    await pumpDay(tester, DateTime(2026, 11, 20));

    await tester.dragFrom(const Offset(640, 400), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 21));
  });

  testWidgets('narrow week falls back to date strip + single-day timeline', (
    tester,
  ) async {
    await pumpWeek(tester, DateTime(2026, 11, 20), size: const Size(800, 1280));
    expect(find.byKey(const ValueKey('week-date-strip')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-header-band')), findsNothing);
  });

  testWidgets('long-press on a plan block only moves vertically', (
    tester,
  ) async {
    final plan = await seed(
      title: 'Move me',
      day: DateTime(2026, 11, 20),
      kind: 'plan',
      startMinute: 600,
      endMinute: 660,
    );
    await pumpDay(tester, DateTime(2026, 11, 20));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('plan-${plan.id}'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 68));
    await gesture.up();
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => repo.getById(plan.id));
    expect(rows!.startMinute, 660);
  });

  testWidgets('short plan block keeps a 44-high hit target', (tester) async {
    final short = await seed(
      title: 'Short',
      day: DateTime(2026, 11, 20),
      kind: 'plan',
      startMinute: 600,
      endMinute: 605,
    );
    await pumpDay(tester, DateTime(2026, 11, 20));
    expect(
      tester.getSize(find.byKey(ValueKey('plan-hit-${short.id}'))).height,
      greaterThanOrEqualTo(44),
    );
  });
}
