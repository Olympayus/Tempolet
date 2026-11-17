import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_buttons.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/ui/app_hairline.dart';
import 'package:tempolet/core/ui/app_list_checkbox.dart';
import 'package:tempolet/core/ui/app_segmented.dart';
import 'package:tempolet/core/ui/app_switch.dart';
import 'package:tempolet/core/ui/strike_through_text.dart';

void main() {
  testWidgets('segmented is 28 high, equal width, taps report value', (
    tester,
  ) async {
    var picked = 'b';
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppSegmented<String>(
            values: const ['a', 'b'],
            labelFor: (v) => Text(v),
            selected: 'a',
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppSegmented<String>)).height, 28);
    final a = tester.getSize(find.widgetWithText(Container, 'a'));
    final b = tester.getSize(find.widgetWithText(Container, 'b'));
    expect(a.width, b.width);
    await tester.tap(find.text('b'));
    expect(picked, 'b');
  });

  testWidgets(
    'segmented is intrinsic and equal-width inside an unbounded Row',
    (tester) async {
      var picked = 'short';
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppSegmented<String>(
                  values: const ['short', 'much longer'],
                  labelFor: (v) => Text(v),
                  selected: 'short',
                  onChanged: (v) => picked = v,
                ),
              ],
            ),
          ),
        ),
      );
      final control = tester.getSize(find.byType(AppSegmented<String>));
      expect(control.height, 28);
      final short = tester.getSize(find.widgetWithText(Container, 'short'));
      final long = tester.getSize(
        find.widgetWithText(Container, 'much longer'),
      );
      expect(short.width, long.width);
      // Intrinsic width, not stretched to the 800px test surface.
      expect(control.width, lessThan(800));
      await tester.tap(find.text('much longer'));
      expect(picked, 'much longer');
    },
  );

  testWidgets('switch is 40x24 and toggles', (tester) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        // A route gives its child tight screen constraints; Center keeps the
        // widget's own size measurable (as the segmented test does).
        home: Center(child: AppSwitch(value: false, onChanged: (v) => on = v)),
      ),
    );
    expect(tester.getSize(find.byType(AppSwitch)), const Size(40, 24));
    await tester.tap(find.byType(AppSwitch));
    expect(on, true);
  });

  testWidgets('check circle is 14 and hit target is 24', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        // See the switch test: Center avoids the route's tight constraints.
        home: Center(
          child: AppCheckCircle(checked: false, onTap: () => taps++),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppCheckCircle)).width, 24);
    expect(
      tester.getSize(find.byKey(const ValueKey('check-circle-glyph'))),
      const Size(14, 14),
    );
    await tester.tap(find.byType(AppCheckCircle));
    expect(taps, 1);
  });

  testWidgets(
    'list checkbox is square, 16px, hit area 24 and keyboard activatable',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppListCheckbox(checked: false, onTap: () => taps++),
          ),
        ),
      );
      final box = tester.getSize(find.byType(AppListCheckbox));
      expect(box, const Size(24, 24));
      final glyph = tester.getSize(
        find.byKey(const ValueKey('list-checkbox-glyph')),
      );
      expect(glyph, const Size(16, 16));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 1);
    },
  );

  testWidgets('hairline is 1px and defaults to the line token', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppHairline())),
    );
    expect(tester.getSize(find.byType(AppHairline)).height, 1);
    final line = tester.widget<Container>(
      find.descendant(
        of: find.byType(AppHairline),
        matching: find.byType(Container),
      ),
    );
    expect(line.color, AppPalette.light.line);
  });

  testWidgets('icon button is 30x30 and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppIconButton(
            icon: const Icon(Icons.add),
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AppIconButton)), const Size(30, 30));
    await tester.tap(find.byType(AppIconButton));
    expect(taps, 1);
  });

  testWidgets('buttons are 30 high and report taps', (tester) async {
    var primary = 0;
    var secondary = 0;
    var link = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.primary(label: 'Create', onPressed: () => primary++),
              AppButton.secondary(
                label: 'Manage',
                onPressed: () => secondary++,
              ),
              AppButton.textLink(label: 'Done', onPressed: () => link++),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.widgetWithText(AppButton, 'Create')).height, 30);
    expect(tester.getSize(find.widgetWithText(AppButton, 'Manage')).height, 30);
    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Manage'));
    await tester.tap(find.text('Done'));
    expect(primary, 1);
    expect(secondary, 1);
    expect(link, 1);
  });

  testWidgets('segmented keeps its size when the selection moves', (
    tester,
  ) async {
    Widget build(String selected) => MaterialApp(
      home: Center(
        child: AppSegmented<String>(
          values: const ['short', 'much longer'],
          labelFor: (v) => Text(v),
          selected: selected,
          onChanged: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(build('short'));
    final shortSelected = tester.getSize(find.byType(AppSegmented<String>));
    expect(
      tester.getSize(find.widgetWithText(Container, 'short')).width,
      tester.getSize(find.widgetWithText(Container, 'much longer')).width,
    );

    // The selected item's 1px border must be reserved on every item, so
    // switching selection between the shortest and longest labels cannot
    // change the control's intrinsic width.
    await tester.pumpWidget(build('much longer'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppSegmented<String>)), shortSelected);
  });

  testWidgets('segmented activates the focused item with Enter and Space', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AppSegmented<String>(
            values: const ['a', 'b'],
            labelFor: (v) => Text(v),
            selected: 'a',
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );

    Focus.of(tester.element(find.text('a'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(picked, 'a');

    picked = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('b'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(picked, 'b');
  });

  testWidgets('switch toggles from the keyboard', (tester) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: AppSwitch(value: false, onChanged: (v) => on = v)),
      ),
    );

    final focus = Focus.of(
      tester.element(
        find.descendant(
          of: find.byType(AppSwitch),
          matching: find.byType(AnimatedContainer),
        ),
      ),
    );
    expect(focus.canRequestFocus, isTrue);
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(on, isTrue);
  });

  testWidgets('buttons activate from the keyboard; disabled ones are skipped', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.primary(label: 'Create', onPressed: () => pressed++),
              const AppButton.secondary(label: 'Disabled'),
            ],
          ),
        ),
      ),
    );

    final focus = Focus.of(tester.element(find.text('Create')));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(pressed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, 2);

    expect(
      Focus.of(tester.element(find.text('Disabled'))).canRequestFocus,
      isFalse,
    );
  });

  testWidgets('strike-through text draws a line that grows with progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: StrikeThroughText(
              text: '寄快递',
              style: const TextStyle(fontSize: 13),
              progress: 0.5,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    final painter = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(StrikeThroughText),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((painter.painter as StrikeLinePainter).progress, 0.5);
  });

  testWidgets('strike line never exceeds an ellipsized CJK title', (
    tester,
  ) async {
    const title = '寄快递到楼下的菜鸟驿站再取回来';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 60,
            child: StrikeThroughText(
              text: title,
              style: TextStyle(fontSize: 13),
              progress: 1,
            ),
          ),
        ),
      ),
    );
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(StrikeThroughText),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter
            as StrikeLinePainter;
    final rendered = tester.getSize(
      find.descendant(
        of: find.byType(StrikeThroughText),
        matching: find.byType(Text),
      ),
    );
    expect(painter.width, lessThanOrEqualTo(rendered.width));
    expect(painter.width, lessThanOrEqualTo(60));
  });

  testWidgets('external progress drives the check fill', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: AppCheckCircle(checked: true, progress: 0.5)),
      ),
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('check-circle-ring')))
          .opacity,
      0.5,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const ValueKey('check-circle-fill')))
          .opacity,
      0.5,
    );
  });

  testWidgets('check circle honours reduced motion and the border override', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Center(
            child: AppCheckCircle(
              checked: false,
              borderColor: AppPalette.light.danger,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    final glyph = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('check-circle-glyph')),
    );
    expect(glyph.duration, Duration.zero);
    final border = (glyph.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, AppPalette.light.danger);
  });
}
