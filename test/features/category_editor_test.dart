import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/app_buttons.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/features/reminders/category_management_page.dart';
import 'package:tempolet/features/reminders/category_order.dart';
import 'package:drift/native.dart';
import 'package:tempolet/data/database/database.dart';

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CategoryManagementPage(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void _useLayout(WidgetTester tester, AppLayout layout, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = layout;
  addTearDown(() => debugLayoutOverride = null);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late CategoryRepository categories;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    categories = CategoryRepository(db);
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

  Future<Category> seed(String name, {int? color}) =>
      categories.create(name: name, color: color);

  testWidgets('tap row opens the unified editor; no inline field or colour '
      'dot action', (tester) async {
    final work = await seed('学习', color: 0xFFE5484D);
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('category-row-${work.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-editor')), findsOneWidget);
    expect(
      find.byKey(ValueKey('category-name-field-${work.id}')),
      findsNothing,
    );
    expect(find.byKey(ValueKey('category-color-${work.id}')), findsNothing);
  });

  testWidgets('duplicate name shows an inline error and save stays disabled', (
    tester,
  ) async {
    await seed('学习');
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    // The edit editor pre-fills its own name, so re-entering it is a no-op;
    // go through the create editor where the field starts empty.
    await tester.tap(find.byKey(const ValueKey('category-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      '学习',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('category-editor-error')), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('category-editor-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('phone opens a bottom sheet', (tester) async {
    final work = await seed('学习');
    _useLayout(tester, AppLayout.phone, const Size(375, 812));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('category-row-${work.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('category-editor-sheet')), findsOneWidget);
  });

  testWidgets('a colour-less category is not dirty until edited', (
    tester,
  ) async {
    final work = await seed('学习');
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('category-row-${work.id}')));
    await tester.pumpAndSettle();
    AppButton save() => tester.widget<AppButton>(
      find.byKey(const ValueKey('category-editor-save')),
    );
    expect(save().onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('category-editor-wheel-sv')));
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('phone creates from the editor sheet', (tester) async {
    _useLayout(tester, AppLayout.phone, const Size(375, 812));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    // The old always-visible bottom input row is gone: creation goes through
    // the same editor sheet as editing.
    expect(find.byKey(const ValueKey('category-create-row')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('category-create')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('category-editor-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('category-editor-name')),
      '新分类',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('category-editor-save')));
    await _settle(tester);
    expect(find.text('新分类'), findsOneWidget);
  });

  testWidgets('long-pressing the row drags it; no handle on tablet', (
    tester,
  ) async {
    final first = await seed('学习');
    final second = await seed('工作');
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(ValueKey('category-handle-${first.id}')), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('category-row-${first.id}'))),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await gesture.moveTo(
      tester.getCenter(find.byKey(ValueKey('category-row-${second.id}'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _settle(tester);

    expect(container.read(categoryOrderProvider).first, second.id);
  });
}
