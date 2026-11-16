import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_buttons.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/ui/app_hairline.dart';
import 'package:tempolet/core/ui/app_segmented.dart';
import 'package:tempolet/core/ui/app_switch.dart';

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

  testWidgets('segmented is intrinsic and equal-width inside an unbounded Row', (
    tester,
  ) async {
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
    final long = tester.getSize(find.widgetWithText(Container, 'much longer'));
    expect(short.width, long.width);
    // Intrinsic width, not stretched to the 800px test surface.
    expect(control.width, lessThan(800));
    await tester.tap(find.text('much longer'));
    expect(picked, 'much longer');
  });

  testWidgets('switch is 40x24 and toggles', (tester) async {
    var on = false;
    await tester.pumpWidget(
      MaterialApp(
        // A route gives its child tight screen constraints; Center keeps the
        // widget's own size measurable (as the segmented test does).
        home: Center(
          child: AppSwitch(value: false, onChanged: (v) => on = v),
        ),
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
              AppButton.secondary(label: 'Manage', onPressed: () => secondary++),
              AppButton.textLink(label: 'Done', onPressed: () => link++),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.widgetWithText(AppButton, 'Create')).height,
      30,
    );
    expect(
      tester.getSize(find.widgetWithText(AppButton, 'Manage')).height,
      30,
    );
    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Manage'));
    await tester.tap(find.text('Done'));
    expect(primary, 1);
    expect(secondary, 1);
    expect(link, 1);
  });
}
