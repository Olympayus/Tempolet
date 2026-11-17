import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/router/app_router.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_buttons.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/ui/strike_through_text.dart';
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
  bool disableAnimations = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: disableAnimations
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: const RemindersPage(),
              ),
            )
          : const RemindersPage(),
    ),
  );
}

/// A two-branch shell matching the app: leaving `/reminders` keeps its page
/// alive in the indexed stack, so only the route listener can clear the
/// retained completions.
GoRouter _testRouter() {
  return GoRouter(
    initialLocation: '/reminders',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reminders',
                builder: (context, state) => const RemindersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/other',
                builder: (context, state) =>
                    const Scaffold(body: SizedBox(key: ValueKey('other-page'))),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _routerApp(ProviderContainer container, GoRouter router) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
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
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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

  testWidgets('uncategorized group dot uses the uncategorized token colour', (
    tester,
  ) async {
    await seed('No category task', date: _today, startMinute: 600);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final dot = tester.widget<Container>(
      find.byKey(
        const ValueKey('reminders-group-dot-$uncategorizedOrderId'),
      ),
    );
    final decoration = dot.decoration! as BoxDecoration;
    expect(decoration.color, kUncategorizedColor);
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

  /// The left column's timeline repeats the card, so completion assertions are
  /// scoped to the right-hand list row.
  Finder rowOf(String id) => find.byKey(ValueKey('reminders-row-$id'));

  Finder rowCircle(String id) =>
      find.descendant(of: rowOf(id), matching: find.byType(AppCheckCircle));

  Finder rowStrike(String id) =>
      find.descendant(of: rowOf(id), matching: find.byType(StrikeThroughText));

  testWidgets('completing keeps the row with strike and counts include it', (
    tester,
  ) async {
    final event = await seed('Finish me', date: _today);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(rowCircle(event.id));
    await _settle(tester);

    expect(rowOf(event.id), findsOneWidget);
    expect(rowStrike(event.id), findsOneWidget);
    // The group count still shows the item and the day/week stats count it.
    expect(find.text('1'), findsWidgets);
    expect(find.text('今日 1'), findsOneWidget);
    expect(find.text('本周 1'), findsOneWidget);
    final stored = await tester.runAsync(() => repo.getById(event.id));
    expect(stored!.isCompleted, isTrue);
  });

  testWidgets('tapping the circle again undoes completion', (tester) async {
    final event = await seed('Undo me', date: _today);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(rowCircle(event.id));
    await _settle(tester);
    expect(rowStrike(event.id), findsOneWidget);

    await tester.tap(rowCircle(event.id));
    await _settle(tester);

    expect(find.byType(StrikeThroughText), findsNothing);
    expect(rowOf(event.id), findsOneWidget);
    final stored = await tester.runAsync(() => repo.getById(event.id));
    expect(stored!.isCompleted, isFalse);
    expect(stored.completedAt, isNull);
  });

  testWidgets(
    'all items completed still shows retained rows instead of the empty state',
    (tester) async {
      final event = await seed('Only task', date: _today);

      await tester.pumpWidget(_pageApp(container));
      await _settle(tester);

      await tester.tap(rowCircle(event.id));
      await _settle(tester);

      expect(find.byKey(const ValueKey('reminders-empty-title')), findsNothing);
      expect(rowOf(event.id), findsOneWidget);
      expect(rowStrike(event.id), findsOneWidget);
    },
  );

  testWidgets(
    'completed overdue item stays in the overdue group while retained',
    (tester) async {
      final event = await seed('Overdue task', date: DateTime(2026, 11, 15));

      await tester.pumpWidget(_pageApp(container));
      await _settle(tester);

      await tester.tap(rowCircle(event.id));
      await _settle(tester);

      expect(
        find.byKey(const ValueKey('reminders-group-__overdue__')),
        findsOneWidget,
      );
      expect(rowOf(event.id), findsOneWidget);
      expect(rowStrike(event.id), findsOneWidget);
      expect(find.text('逾期 1'), findsOneWidget);
    },
  );

  testWidgets('leaving the page clears retained rows', (tester) async {
    final event = await seed('Clear me', date: _today);
    final router = _testRouter();
    addTearDown(router.dispose);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(_today),
        routerProvider.overrideWithValue(router),
      ],
    );

    await tester.pumpWidget(_routerApp(container, router));
    await _settle(tester);

    await tester.tap(rowCircle(event.id));
    await _settle(tester);
    expect(rowStrike(event.id), findsOneWidget);

    router.go('/other');
    await _settle(tester);
    expect(find.byKey(const ValueKey('other-page')), findsOneWidget);

    router.go('/reminders');
    await _settle(tester);

    expect(rowOf(event.id), findsNothing);
    expect(find.byType(StrikeThroughText), findsNothing);
  });

  testWidgets('left column keeps completed cards, counts them, and undoes', (
    tester,
  ) async {
    final event = await seed('Timeline task', date: _today, startMinute: 540);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final card = find.byKey(ValueKey('reminders-timeline-event-${event.id}'));
    final title = find.byKey(const ValueKey('reminders-timeline-title'));
    expect(tester.widget<Text>(title).data, contains('1 项'));

    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(ValueKey('complete-${event.id}')),
      ),
    );
    await _settle(tester);

    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(StrikeThroughText)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(title).data, contains('1 项'));

    await tester.tap(
      find.descendant(
        of: card,
        matching: find.byKey(ValueKey('complete-${event.id}')),
      ),
    );
    await _settle(tester);

    expect(
      find.descendant(of: card, matching: find.byType(StrikeThroughText)),
      findsNothing,
    );
    final stored = await tester.runAsync(() => repo.getById(event.id));
    expect(stored!.isCompleted, isFalse);
  });

  testWidgets('timeline card can complete, undo, and complete again', (
    tester,
  ) async {
    final event = await seed('Cycle task', date: _today, startMinute: 540);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final card = find.byKey(ValueKey('reminders-timeline-event-${event.id}'));
    final circleKey = find.descendant(
      of: card,
      matching: find.byKey(ValueKey('complete-${event.id}')),
    );
    Finder strike() =>
        find.descendant(of: card, matching: find.byType(StrikeThroughText));
    bool circleChecked() => tester
        .widget<AppCheckCircle>(
          find.descendant(of: card, matching: find.byType(AppCheckCircle)),
        )
        .checked;
    // The card's own fade-out must not stick once the page owns the retained
    // snapshot.
    double cardOpacity() => tester
        .widget<AnimatedOpacity>(
          find
              .descendant(of: card, matching: find.byType(AnimatedOpacity))
              .first,
        )
        .opacity;

    await tester.tap(circleKey);
    await _settle(tester);

    expect(circleChecked(), isTrue);
    expect(strike(), findsOneWidget);
    expect(cardOpacity(), 1);

    await tester.tap(circleKey);
    await _settle(tester);

    // Undo restores the pending look: un-ticked, no strike, full opacity.
    expect(circleChecked(), isFalse);
    expect(strike(), findsNothing);
    expect(cardOpacity(), 1);
    final undoneTitle = tester.widget<Text>(
      find.descendant(of: card, matching: find.text('Cycle task')),
    );
    expect(undoneTitle.style?.decoration, isNull);
    final undone = await tester.runAsync(() => repo.getById(event.id));
    expect(undone!.isCompleted, isFalse);

    // The same card must be able to complete again.
    await tester.tap(circleKey);
    await _settle(tester);

    expect(circleChecked(), isTrue);
    expect(strike(), findsOneWidget);
    expect(cardOpacity(), 1);
    final recompleted = await tester.runAsync(() => repo.getById(event.id));
    expect(recompleted!.isCompleted, isTrue);
  });

  testWidgets('reduce motion jumps straight to the completed state', (
    tester,
  ) async {
    final event = await seed('Instant task', date: _today);

    await tester.pumpWidget(_pageApp(container, disableAnimations: true));
    await _settle(tester);

    await tester.tap(rowCircle(event.id));
    await tester.runAsync(() async {
      while (!(await repo.getById(event.id))!.isCompleted) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    // A single frame after the completion write: no animation ticks.
    await tester.pump();

    final strike = tester.widget<StrikeThroughText>(rowStrike(event.id));
    expect(strike.progress, 1);
    final circle = tester.widget<AppCheckCircle>(rowCircle(event.id));
    expect(circle.checked, isTrue);
    final glyph = tester.widget<AnimatedContainer>(
      find.descendant(
        of: rowOf(event.id),
        matching: find.byKey(const ValueKey('check-circle-glyph')),
      ),
    );
    expect(
      (glyph.decoration! as BoxDecoration).color,
      Theme.of(tester.element(rowOf(event.id))).colorScheme.primary,
    );
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
