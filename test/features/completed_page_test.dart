import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/ui/app_list_checkbox.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/completed/completed_page.dart';
import 'package:tempolet/features/events/event_list_row.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _pageApp(
  ProviderContainer container, {
  Locale locale = const Locale('zh'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CompletedPage(),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late FakeNotificationService notifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed(
    String title, {
    String kind = 'reminder',
    int? startMinute = 540,
    int? endMinute,
    DateTime? date,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: date ?? dateOnly(DateTime.now()),
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: 0,
    );
  }

  Future<void> completeAt(String id, DateTime at) async {
    await (db.update(db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(isCompleted: const Value(true), completedAt: Value(at)),
    );
  }

  testWidgets('groups items into 今天, 昨天 and 更早 in completion order', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final earlier = DateTime(today.year, today.month, today.day - 3);

    final newest = await seed(
      'Today task',
      kind: 'plan',
      startMinute: 600,
      endMinute: 660,
    );
    final middle = await seed('Yesterday task');
    final oldest = await seed('Earlier task');
    await completeAt(
      newest.id,
      DateTime(today.year, today.month, today.day, 9, 30),
    );
    await completeAt(
      middle.id,
      DateTime(yesterday.year, yesterday.month, yesterday.day, 18),
    );
    await completeAt(
      oldest.id,
      DateTime(earlier.year, earlier.month, earlier.day, 12),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-clear')), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('更早'), findsOneWidget);

    expect(find.text('Today task'), findsOneWidget);
    expect(find.text('Yesterday task'), findsOneWidget);
    expect(find.text('Earlier task'), findsOneWidget);
    // Each row names the item's kind and its own schedule, not just the
    // completion day (`10-ui-refinement` §9.5).
    final todayLabel = '${today.month}月${today.day}日';
    expect(find.text('计划 · $todayLabel 10:00–11:00'), findsOneWidget);
    expect(find.text('提醒 · $todayLabel 09:00'), findsNWidgets(2));
    // Every completed row carries its full completion date and time, even
    // though the group header already names the day (user requirement,
    // design spec §7.5).
    expect(find.textContaining('09:30'), findsOneWidget);
    expect(find.textContaining('18:00'), findsOneWidget);
    expect(find.textContaining('12:00'), findsOneWidget);
    expect(find.textContaining(' 完成'), findsNWidgets(3));

    double rowTop(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('completed-restore-$id'))).dy;
    expect(rowTop(newest.id), lessThan(rowTop(middle.id)));
    expect(rowTop(middle.id), lessThan(rowTop(oldest.id)));
  });

  testWidgets('restore is a 30px circular-arrow icon button', (tester) async {
    final event = await seed('Dated task');
    await completeAt(event.id, DateTime(2026, 11, 16, 10, 2));

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final restore = find.byKey(ValueKey('completed-restore-${event.id}'));
    expect(restore, findsOneWidget);
    expect(find.textContaining('11月16日 10:02'), findsOneWidget);
    expect(find.text('11月16日 10:02 完成'), findsOneWidget);
    final today = dateOnly(DateTime.now());
    expect(
      find.text('提醒 · ${today.month}月${today.day}日 09:00'),
      findsOneWidget,
    );

    // Design §9.5: a 30×30 accent circular-arrow button, not a text link.
    expect(tester.getSize(restore), const Size(30, 30));
    final icon = tester.widget<Icon>(
      find.descendant(of: restore, matching: find.byType(Icon)),
    );
    expect(icon.icon, LucideIcons.rotateCcw);
    expect(icon.size, 15);
    expect(icon.color, Theme.of(tester.element(restore)).colorScheme.primary);
    expect(
      find.descendant(of: restore, matching: find.text('恢复')),
      findsNothing,
    );
  });

  testWidgets('English completed rows use the no-comma separator', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    final event = await seed(
      'English task',
      date: DateTime(2026, 11, 13),
      startMinute: 540,
    );
    await completeAt(event.id, DateTime(2026, 11, 16, 16, 20));

    await tester.pumpWidget(_pageApp(container, locale: const Locale('en')));
    await _settle(tester);

    expect(find.text('Reminder · Nov 13 · 09:00'), findsOneWidget);
    expect(find.text('completed Nov 16 · 16:20'), findsOneWidget);
  });

  testWidgets('long press enters multi-select with select all and delete', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Done one');
    final second = await seed('Done two');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);
    expect(find.byKey(const ValueKey('completed-selection-bar')), findsNothing);

    await tester.longPress(find.byType(EventListRow).first);
    await tester.pumpAndSettle();

    expect(find.text('全选'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('completed-selection-bar')),
      findsOneWidget,
    );
    // The pressed row starts selected; the normal header actions give way to
    // the selection header.
    expect(find.text('已选 1 项'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.text('清空'), findsNothing);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('completed-selection-bar')), findsNothing);
    expect(find.text('清空'), findsOneWidget);
  });

  testWidgets('multi-select delete confirms, cancels and removes selected', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Batch A');
    final second = await seed('Batch B');
    final kept = await seed('Batch C');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );
    await completeAt(kept.id, DateTime(today.year, today.month, today.day, 11));

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.longPress(find.text('Batch A'));
    await tester.pumpAndSettle();
    // Select only the first two rows; the third stays unselected.
    await tester.tap(find.text('Batch B'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-batch-delete')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-confirm-delete')));
    await _settle(tester);

    expect(find.text('Batch A'), findsNothing);
    expect(find.text('Batch B'), findsNothing);
    expect(find.text('Batch C'), findsOneWidget);
    expect(await tester.runAsync(() => repo.getById(first.id)), isNull);
    expect(await tester.runAsync(() => repo.getById(second.id)), isNull);
    expect(await tester.runAsync(() => repo.getById(kept.id)), isNotNull);
    expect(
      notifications.cancelled,
      containsAll([first.notificationId, second.notificationId]),
    );
    expect(notifications.cancelled, isNot(contains(kept.notificationId)));
  });

  testWidgets('multi-select restore returns every selected item', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Restore A');
    final second = await seed('Restore B');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('completed-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completed-select-all')));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-batch-restore')));
    await _settle(tester);

    final restoredFirst = await tester.runAsync(() => repo.getById(first.id));
    final restoredSecond = await tester.runAsync(() => repo.getById(second.id));
    expect(restoredFirst!.isCompleted, isFalse);
    expect(restoredFirst.completedAt, isNull);
    expect(restoredSecond!.isCompleted, isFalse);
    expect(find.text('还没有已完成事项'), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-selection-bar')), findsNothing);
  });

  testWidgets(
    'clear selection empties every selection without leaving select mode',
    (tester) async {
      final today = dateOnly(DateTime.now());
      final first = await seed('Done A');
      final second = await seed('Done B');
      final third = await seed('Done C');
      await completeAt(
        first.id,
        DateTime(today.year, today.month, today.day, 9),
      );
      await completeAt(
        second.id,
        DateTime(today.year, today.month, today.day, 10),
      );
      await completeAt(
        third.id,
        DateTime(today.year, today.month, today.day, 11),
      );

      await tester.pumpWidget(_pageApp(container));
      await _settle(tester);

      await tester.tap(find.byKey(const ValueKey('completed-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('completed-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('已选 3 项'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('completed-clear-selection')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('completed-selected-count')),
        findsOneWidget,
      );
      expect(find.text('已选 0 项'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('completed-selection-bar')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Escape leaves select mode', (tester) async {
    final today = dateOnly(DateTime.now());
    final event = await seed('Esc task');
    await completeAt(event.id, DateTime(today.year, today.month, today.day, 9));

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('completed-select')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('completed-selection-bar')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completed-selection-bar')), findsNothing);
    expect(find.byKey(const ValueKey('completed-select')), findsOneWidget);
  });

  testWidgets('selection mode rows use the square checkbox', (tester) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Checkbox A');
    final second = await seed('Checkbox B');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);
    expect(find.byType(AppListCheckbox), findsNothing);

    await tester.tap(find.byKey(const ValueKey('completed-select')));
    await tester.pumpAndSettle();

    expect(find.byType(AppListCheckbox), findsNWidgets(2));
    expect(find.byType(AppCheckCircle), findsNothing);
  });

  testWidgets('restore clears the completion and returns the item to its day', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final event = await seed('Call back');
    await completeAt(
      event.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('completed-restore-${event.id}')));
    await _settle(tester);

    expect(find.byKey(ValueKey('completed-restore-${event.id}')), findsNothing);
    final restored = await tester.runAsync(() => repo.getById(event.id));
    expect(restored!.isCompleted, isFalse);
    expect(restored.completedAt, isNull);
    final dayEvents = await tester.runAsync(() => repo.eventsOnDay(today));
    expect(dayEvents!.map((e) => e.id), [event.id]);
    expect(notifications.cancelled, contains(event.notificationId));
  });

  testWidgets('delete asks for confirmation and hard deletes the row', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final event = await seed('Delete me');
    await completeAt(
      event.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('completed-delete-${event.id}')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-confirm-cancel')));
    await _settle(tester);
    expect(
      find.byKey(ValueKey('completed-restore-${event.id}')),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => repo.getById(event.id)), isNotNull);

    await tester.tap(find.byKey(ValueKey('completed-delete-${event.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completed-confirm-delete')));
    await _settle(tester);

    expect(find.byKey(ValueKey('completed-restore-${event.id}')), findsNothing);
    expect(await tester.runAsync(() => repo.getById(event.id)), isNull);
    expect(notifications.cancelled, contains(event.notificationId));
  });

  testWidgets('clear asks for confirmation, cancels and empties the list', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Done A');
    final second = await seed('Done B');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('completed-clear')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-confirm-cancel')));
    await _settle(tester);
    expect(
      await tester.runAsync(() => db.select(db.events).get()),
      hasLength(2),
    );

    await tester.tap(find.byKey(const ValueKey('completed-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completed-confirm-delete')));
    await _settle(tester);

    expect(find.text('Done A'), findsNothing);
    expect(find.text('Done B'), findsNothing);
    expect(await tester.runAsync(() => db.select(db.events).get()), isEmpty);
    expect(
      notifications.cancelled,
      containsAll([first.notificationId, second.notificationId]),
    );
  });

  testWidgets('sidebar link opens the completed page and back returns', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TempoletApp(),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-completed-link')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('completed-back')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
  });
}
