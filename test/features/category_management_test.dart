import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/reminders/category_management_page.dart';
import 'package:tempolet/features/reminders/category_order.dart';

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
      home: const CategoryManagementPage(),
    ),
  );
}

Finder _row(String id) => find.byKey(ValueKey('category-row-$id'));

double _rowTop(WidgetTester tester, String id) =>
    tester.getTopLeft(_row(id)).dy;

String _countOf(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(ValueKey('category-count-$id'))).data!;

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late CategoryRepository categories;
  late EventRepository events;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(db);
    events = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertCategory(
    String id,
    String name, {
    int? color,
    int sortOrder = 0,
  }) async {
    final now = DateTime(2026, 11, 16);
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            color: Value(color),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  testWidgets('category rows are 46 high and uncategorized cannot be deleted', (
    tester,
  ) async {
    await insertCategory('work', 'Work');

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(tester.getSize(_row('work')).height, 46);
    expect(_row(uncategorizedOrderId), findsOneWidget);
    expect(find.text('未分类'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('category-delete-uncategorized')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('category-delete-$uncategorizedOrderId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('category-color-$uncategorizedOrderId')),
      findsNothing,
    );
    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('新建分类'), findsOneWidget);
  });

  testWidgets('the sentinel follows its persisted position', (tester) async {
    await insertCategory('work', 'Work');
    await prefs.setStringList(CategoryOrderController.prefKey, [
      uncategorizedOrderId,
      'work',
    ]);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(
      _rowTop(tester, uncategorizedOrderId),
      lessThan(_rowTop(tester, 'work')),
    );
  });

  testWidgets('rows show per-category counts, unknown ids fold into 未分类', (
    tester,
  ) async {
    await insertCategory('work', 'Work');
    await insertCategory('personal', 'Personal');
    await events.create(
      title: 'Work item',
      kind: 'reminder',
      date: DateTime(2026, 11, 16),
      categoryId: 'work',
    );
    await events.create(
      title: 'Loose item',
      kind: 'reminder',
      date: DateTime(2026, 11, 16),
    );
    await events.create(
      title: 'Stale item',
      kind: 'reminder',
      date: DateTime(2026, 11, 16),
      categoryId: 'missing-category',
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(_countOf(tester, 'work'), '1');
    expect(_countOf(tester, 'personal'), '0');
    expect(_countOf(tester, uncategorizedOrderId), '2');
  });

  testWidgets('the header button creates a category above 未分类', (tester) async {
    await insertCategory('work', 'Work');

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('category-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      'Personal',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);

    final added = (await tester.runAsync(() => categories.watchAll().first))!
        .firstWhere((category) => category.name == 'Personal');
    expect(_row(added.id), findsOneWidget);
    expect(
      _rowTop(tester, added.id),
      lessThan(_rowTop(tester, uncategorizedOrderId)),
    );
    expect(find.byKey(const ValueKey('category-editor')), findsNothing);
  });

  testWidgets('a duplicate name keeps the dialog open with an error', (
    tester,
  ) async {
    await insertCategory('work', 'Work');

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('category-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      'Work',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('category-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('category-editor-error')), findsOneWidget);
    expect(find.text('分类名称已存在'), findsOneWidget);
  });

  testWidgets('row tap opens the editor and renames; conflict keeps the name', (
    tester,
  ) async {
    await insertCategory('work', 'Work');
    await insertCategory('personal', 'Personal');

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(_row('work'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      'Office',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);
    expect(find.text('Office'), findsOneWidget);

    await tester.tap(_row('work'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      'personal',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);

    final names = (await tester.runAsync(() => categories.watchAll().first))!
        .map((category) => category.name)
        .toList();
    expect(names, ['Office', 'Personal']);
    expect(find.byKey(const ValueKey('category-editor-error')), findsOneWidget);
  });

  testWidgets('deleting a category soft-deletes it and frees its events', (
    tester,
  ) async {
    await insertCategory('work', 'Work');
    final event = await events.create(
      title: 'Work item',
      kind: 'reminder',
      date: DateTime(2026, 11, 16),
      categoryId: 'work',
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('category-delete-work')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('category-delete-confirm')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('category-delete-confirm-action')),
    );
    await _settle(tester);

    expect(_row('work'), findsNothing);
    final remaining = (await tester.runAsync(
      () => categories.watchAll().first,
    ))!;
    expect(remaining, isEmpty);
    final detached = await tester.runAsync(() => events.getById(event.id));
    expect(detached!.categoryId, isNull);
  });

  testWidgets('the editor palette saves the picked colour', (tester) async {
    await insertCategory('work', 'Work', color: 0xFF007AFF);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(_row('work'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-editor')), findsOneWidget);
    // The preset swatches are gone; a colour comes from the wheel's 「高级」
    // HEX entry, which is exact and easy to assert.
    await tester.tap(
      find.byKey(const ValueKey('category-editor-wheel-advanced')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-wheel-hex')),
      '#123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);

    final saved = (await tester.runAsync(() => categories.watchAll().first))!
        .single;
    expect(saved.color, 0xFF123456);
  });

  testWidgets(
    'long-press drag reorders the sentinel-aware list and sortOrder',
    (tester) async {
      await insertCategory('work', 'Work', sortOrder: 0);
      await insertCategory('personal', 'Personal', sortOrder: 1);

      await tester.pumpWidget(_pageApp(container));
      await _settle(tester);

      expect(_rowTop(tester, 'work'), lessThan(_rowTop(tester, 'personal')));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('category-row-work'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(tester.getCenter(_row('personal')));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await _settle(tester);

      expect(container.read(categoryOrderProvider), [
        'personal',
        'work',
        uncategorizedOrderId,
      ]);
      expect(_rowTop(tester, 'personal'), lessThan(_rowTop(tester, 'work')));

      final saved = (await tester.runAsync(() => categories.watchAll().first))!;
      expect(saved.map((category) => category.name), ['Personal', 'Work']);
    },
  );

  testWidgets('the 未分类 system row itself can be dragged', (tester) async {
    await insertCategory('work', 'Work');

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(ValueKey('category-row-$uncategorizedOrderId')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(_row('work')));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _settle(tester);

    expect(container.read(categoryOrderProvider), [
      uncategorizedOrderId,
      'work',
    ]);
  });
}
