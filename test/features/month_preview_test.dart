import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_preview_dialog.dart';
import 'package:tempolet/features/events/fields/segmented_date_field.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

class _PreviewHost extends StatelessWidget {
  const _PreviewHost({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MonthPreviewDialog(day: day),
            ),
            child: const Text('open-preview'),
          ),
        ),
      ),
    );
  }
}

Widget _app(ProviderContainer container, DateTime day) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _PreviewHost(day: day),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late Event alpha;
  late Event bravo;

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
    alpha = await repo.create(
      title: 'Alpha',
      kind: 'plan',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      endMinute: 600,
    );
    bravo = await repo.create(
      title: 'Bravo',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 630,
    );
    await repo.create(
      title: 'Charlie',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 750,
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> openPreview(WidgetTester tester, DateTime day) async {
    await tester.pumpWidget(_app(container, day));
    await _settle(tester);
    await tester.tap(find.text('open-preview'));
    await _settle(tester);
  }

  testWidgets('shows the day header, count, rows and complete circles', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    expect(find.text('Nov 11 Wed'), findsOneWidget);
    expect(find.text('· 3 items'), findsOneWidget);
    expect(find.text('09:00–10:00'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
    expect(
      find.byKey(ValueKey('preview-complete-${alpha.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('preview-complete-${bravo.id}')),
      findsOneWidget,
    );
  });

  testWidgets('shows the today pill for the current day', (tester) async {
    await openPreview(tester, dateOnly(DateTime.now()));

    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('close button closes the preview', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.byKey(const ValueKey('month-preview-close')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
  });

  testWidgets('escape closes the preview', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
  });

  testWidgets('tapping a row opens the shared editor', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.text('Bravo'));
    await _settle(tester);

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
  });

  testWidgets('add opens the editor on the previewed day', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.byKey(const ValueKey('preview-add')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedDateField>(find.byKey(const ValueKey('editor-date')))
          .value,
      DateTime(2026, 11, 11),
    );
  });

  testWidgets('edit in sidebar closes, selects the day and opens the sidebar', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.byKey(const ValueKey('preview-edit-sidebar')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 11));
    expect(container.read(sidebarPreferenceProvider), isTrue);
  });

  testWidgets(
    'completion state follows its event when an earlier row appears',
    (tester) async {
      await openPreview(tester, DateTime(2026, 11, 11));

      // Complete the 10:30 row, then insert an 08:00 row above it. Unkeyed rows
      // would carry the 'completing' state down to a different event.
      await tester.tap(find.byKey(ValueKey('preview-complete-${bravo.id}')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );

      final earlier = await repo.create(
        title: 'Aardvark',
        kind: 'reminder',
        date: DateTime(2026, 11, 11),
        startMinute: 480,
      );
      await _settle(tester);

      await tester.tap(find.byKey(ValueKey('preview-complete-${alpha.id}')));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );

      final completed = await tester.runAsync(() => repo.getById(alpha.id));
      final open = await tester.runAsync(() => repo.getById(earlier.id));
      expect(completed!.isCompleted, isTrue);
      expect(open!.isCompleted, isFalse);
    },
  );

  testWidgets('closing during the fade still writes the completion', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.byKey(ValueKey('preview-complete-${alpha.id}')));
    await tester.pump(const Duration(milliseconds: 20));
    // Tear the dialog down before the 120ms fade finishes; the write must
    // still happen without touching `ref` after disposal.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    final completed = await tester.runAsync(() => repo.getById(alpha.id));
    expect(completed!.isCompleted, isTrue);
  });

  testWidgets('long days scroll inside the dialog and keep actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 9; i++) {
      await repo.create(
        title: 'Extra$i',
        kind: 'reminder',
        date: DateTime(2026, 11, 11),
        startMinute: 480 + i * 15,
      );
    }

    await openPreview(tester, DateTime(2026, 11, 11));

    expect(find.byKey(const ValueKey('month-preview-scroll')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Extra8'),
      50,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('month-preview-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Extra8'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The footer stays pinned while the rows scroll, so it remains tappable.
    await tester.tap(find.byKey(const ValueKey('preview-edit-sidebar')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
  });
}
