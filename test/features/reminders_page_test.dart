import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_buttons.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/reminders/category_order.dart';
import 'package:tempolet/features/reminders/reminders_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);

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
      home: const RemindersPage(),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The left column's timeline repeats event titles, so category-list
/// assertions are scoped to the right-hand list.
Finder _inCategoryList(Finder matching) => find.descendant(
  of: find.byKey(const ValueKey('reminders-category-mode')),
  matching: matching,
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late CategoryRepository categories;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    categories = CategoryRepository(db);
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

  Future<Event> seed(
    String title, {
    String kind = 'reminder',
    required DateTime date,
    int? startMinute = 540,
    int? endMinute,
    String? categoryId,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: 0,
      categoryId: categoryId,
    );
  }

  testWidgets('reminders page shows overdue first with danger count', (
    tester,
  ) async {
    await seed('Overdue task', date: DateTime(2026, 11, 15));
    await seed('Today task', date: _today, startMinute: 600);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(find.byKey(const ValueKey('reminders-page')), findsOneWidget);
    expect(find.text('提醒与计划'), findsOneWidget);
    // The stats unit reads `逾期 1`; the group header is the plain `逾期`.
    expect(find.text('逾期'), findsOneWidget);
    expect(find.text('逾期 1'), findsOneWidget);
    expect(find.text('今日 1'), findsOneWidget);
    expect(find.text('本周 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-new')), findsOneWidget);
    expect(find.byTooltip('分类管理'), findsOneWidget);
    expect(find.byTooltip('查看已完成'), findsOneWidget);
    expect(
      tester
          .widget<AppIconButton>(
            find.byKey(const ValueKey('reminders-manage-categories')),
          )
          .onPressed,
      isNotNull,
    );

    final overdueX = tester
        .getTopLeft(find.byKey(const ValueKey('reminders-stat-overdue')))
        .dx;
    final todayX = tester
        .getTopLeft(find.byKey(const ValueKey('reminders-stat-today')))
        .dx;
    final weekX = tester
        .getTopLeft(find.byKey(const ValueKey('reminders-stat-week')))
        .dx;
    expect(overdueX, lessThan(todayX));
    expect(todayX, lessThan(weekX));

    expect(find.text('Overdue task'), findsOneWidget);
    expect(find.text('11月15日 09:00'), findsOneWidget);
    final overdueTime = tester.widget<Text>(find.text('11月15日 09:00'));
    expect(overdueTime.style?.color, AppPalette.light.danger);
  });

  test(
    'applyOrder honours the uncategorized sentinel among real categories',
    () async {
      final work = await categories.create(name: 'Work');
      final personal = await categories.create(name: 'Personal');
      final controller = container.read(categoryOrderProvider.notifier);
      controller.setOrder([uncategorizedOrderId, work.id]);

      final ordered = controller.applyOrder([personal, work]);

      expect(ordered.map((category) => category?.id ?? uncategorizedOrderId), [
        uncategorizedOrderId,
        work.id,
        personal.id,
      ]);
    },
  );

  test('applyOrder defaults to real categories then uncategorized', () async {
    final work = await categories.create(name: 'Work');
    final personal = await categories.create(name: 'Personal');
    final controller = container.read(categoryOrderProvider.notifier);

    final ordered = controller.applyOrder([work, personal]);

    expect(ordered.map((category) => category?.id ?? uncategorizedOrderId), [
      work.id,
      personal.id,
      uncategorizedOrderId,
    ]);
  });

  testWidgets('uncategorized group is last when no order is persisted', (
    tester,
  ) async {
    final work = await categories.create(name: 'Work');
    await seed('No category task', date: _today, startMinute: 600);
    await seed(
      'Work task',
      date: _today,
      startMinute: 700,
      categoryId: work.id,
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final workY = tester
        .getTopLeft(find.byKey(ValueKey('reminders-group-${work.id}')))
        .dy;
    final uncategorizedY = tester
        .getTopLeft(
          find.byKey(const ValueKey('reminders-group-$uncategorizedOrderId')),
        )
        .dy;
    expect(workY, lessThan(uncategorizedY));
  });

  testWidgets('events far in the future still appear in their category group', (
    tester,
  ) async {
    final work = await categories.create(name: 'Work');
    final farFuture = DateTime(_today.year, _today.month + 18, _today.day);
    await seed(
      'Far future task',
      date: farFuture,
      startMinute: 600,
      categoryId: work.id,
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(find.text('Far future task'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-empty-title')), findsNothing);
  });

  testWidgets('uncategorized can be ordered among real categories', (
    tester,
  ) async {
    final work = await categories.create(name: 'Work');
    await seed('No category task', date: _today, startMinute: 600);
    await seed(
      'Work task',
      date: _today,
      startMinute: 700,
      categoryId: work.id,
    );
    container.read(categoryOrderProvider.notifier).setOrder([
      uncategorizedOrderId,
      work.id,
    ]);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final uncategorizedY = tester
        .getTopLeft(
          find.byKey(const ValueKey('reminders-group-$uncategorizedOrderId')),
        )
        .dy;
    final workY = tester
        .getTopLeft(find.byKey(ValueKey('reminders-group-${work.id}')))
        .dy;
    expect(uncategorizedY, lessThan(workY));
    expect(find.text('未分类'), findsOneWidget);
    expect(_inCategoryList(find.text('No category task')), findsOneWidget);
    expect(_inCategoryList(find.text('Work task')), findsOneWidget);
  });

  testWidgets('filter segmented hides plans and reminders', (tester) async {
    await seed('Reminder A', date: _today, startMinute: 600);
    await seed(
      'Plan A',
      kind: 'plan',
      date: _today,
      startMinute: 700,
      endMinute: 760,
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(_inCategoryList(find.text('Reminder A')), findsOneWidget);
    expect(_inCategoryList(find.text('Plan A')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-filter')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-mode')), findsOneWidget);

    await tester.tap(find.text('计划'));
    await _settle(tester);
    expect(_inCategoryList(find.text('Plan A')), findsOneWidget);
    expect(_inCategoryList(find.text('Reminder A')), findsNothing);

    await tester.tap(find.text('提醒'));
    await _settle(tester);
    expect(_inCategoryList(find.text('Reminder A')), findsOneWidget);
    expect(_inCategoryList(find.text('Plan A')), findsNothing);

    await tester.tap(find.text('全部'));
    await _settle(tester);
    expect(_inCategoryList(find.text('Reminder A')), findsOneWidget);
    expect(_inCategoryList(find.text('Plan A')), findsOneWidget);
  });

  testWidgets('group toggle collapses and reopens its rows', (tester) async {
    await seed('Collapsible task', date: _today);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(_inCategoryList(find.text('Collapsible task')), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('reminders-group-toggle-$uncategorizedOrderId'),
      ),
    );
    await _settle(tester);
    expect(_inCategoryList(find.text('Collapsible task')), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey('reminders-group-toggle-$uncategorizedOrderId'),
      ),
    );
    await _settle(tester);
    expect(_inCategoryList(find.text('Collapsible task')), findsOneWidget);
  });

  testWidgets('empty state offers a new action', (tester) async {
    await tester.pumpWidget(_pageApp(container, locale: const Locale('en')));
    await _settle(tester);

    expect(find.text('Reminders & Plans'), findsOneWidget);
    expect(find.text('No reminders yet'), findsOneWidget);
    expect(find.text('＋ New'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-empty-new')), findsOneWidget);
  });

  testWidgets('left column hosts the mini calendar and timeline', (
    tester,
  ) async {
    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('reminders-left-column'))).width,
      204,
    );
    final calendar = find.byKey(const ValueKey('reminders-mini-calendar'));
    expect(calendar, findsOneWidget);
    expect(tester.getSize(calendar).width, 180);
    expect(find.byKey(const ValueKey('reminders-timeline')), findsOneWidget);
    final leftColumn = tester.widget<Container>(
      find.byKey(const ValueKey('reminders-left-column')),
    );
    expect(
      (leftColumn.decoration! as BoxDecoration).color,
      AppPalette.light.side,
    );
  });

  testWidgets('checking a row completes it and removes it from the list', (
    tester,
  ) async {
    final event = await seed('Finish me', date: _today);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byType(AppCheckCircle));
    await _settle(tester);

    expect(find.text('Finish me'), findsNothing);
    final stored = await tester.runAsync(() => repo.getById(event.id));
    expect(stored!.isCompleted, isTrue);
  });

  testWidgets('row tap opens the shared event editor', (tester) async {
    final event = await seed('Open me', date: _today);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('reminders-row-${event.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
  });

  testWidgets('group add opens the editor preselected to the category', (
    tester,
  ) async {
    final work = await categories.create(name: 'Work');
    await seed('Work task', date: _today, categoryId: work.id);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('reminders-group-add-${work.id}')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('editor-category')),
        matching: find.text('Work'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('showDate rows use the dot separator in English', (tester) async {
    await seed('Overdue task', date: DateTime(2026, 11, 15));

    await tester.pumpWidget(_pageApp(container, locale: const Locale('en')));
    await _settle(tester);

    expect(find.text('Nov 15 · 09:00'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('rail bell opens the reminders page and settings still works', (
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
    await tester.tap(find.byKey(const ValueKey('rail-reminders')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('reminders-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminders-title')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-settings')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
  });
}
