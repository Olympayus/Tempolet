import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_theme.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_view.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(AppPalette.light.accent),
      home: const Scaffold(body: MonthView()),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 11));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('month view golden', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await repo.create(
      title: 'Design review',
      kind: 'plan',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      endMinute: 600,
    );
    await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 870,
    );
    await repo.create(
      title: 'Ship v0.1.2',
      kind: 'reminder',
      date: DateTime(2026, 11, 18),
    );

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await expectLater(
      find.byType(MonthView),
      matchesGoldenFile('goldens/month_view.png'),
    );
  });
}
