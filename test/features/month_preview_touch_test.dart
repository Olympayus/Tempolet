import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_view.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);
final _target = DateTime(2026, 11, 20);

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MonthView()),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void _useTablet(WidgetTester tester, {Size size = const Size(1280, 800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = AppLayout.tablet;
  addTearDown(() => debugLayoutOverride = null);
}

void main() {
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
        todayProvider.overrideWithValue(_today),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await repo.create(
        title: 'Item $i',
        kind: 'reminder',
        date: _target,
        startMinute: 540 + i * 15,
        reminderOffsetMinutes: 0,
      );
    }
  }

  testWidgets('long-press shows a read-only preview until finger up', (
    tester,
  ) async {
    await seed(2);
    _useTablet(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-20'))),
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-preview-close')), findsNothing);
    expect(find.byType(AppCheckCircle), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
    // The preview never changes the selected day.
    expect(container.read(selectedDayProvider), _today);
  });

  testWidgets('overflowing preview shows the remaining count', (tester) async {
    await seed(9);
    // A short tablet window leaves room for 8 preview rows; the ninth item
    // must collapse into the 「还有 N 项」 line instead of scrolling.
    _useTablet(tester, size: const Size(1280, 480));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-20'))),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    expect(find.textContaining('Item'), findsWidgets);
    expect(find.textContaining('还有'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
