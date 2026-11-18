import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_dropdown.dart';

const _panelKey = ValueKey('app-dropdown-panel');
const _triggerKey = ValueKey('app-dropdown-trigger');
const _chevronKey = ValueKey('app-dropdown-chevron');

/// Hosts the dropdown in front of an opaque full-screen background so an
/// outside tap has somewhere to land after the popover layer ignores it.
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        Center(child: child),
      ],
    ),
  ),
);

Widget _dropdown({
  double triggerHeight = 34,
  ValueChanged<String>? onChanged,
}) => SizedBox(
  width: 160,
  child: AppDropdown<String>(
    value: 'a',
    items: const [
      AppDropdownItem(value: 'a', label: 'A'),
      AppDropdownItem(value: 'b', label: 'B'),
    ],
    onChanged: onChanged ?? (_) {},
    triggerHeight: triggerHeight,
  ),
);

void main() {
  testWidgets('dropdown opens 220-wide panel, selects, closes on escape', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppDropdown<String>(
            value: 'a',
            items: const [
              AppDropdownItem(value: 'a', label: 'A'),
              AppDropdownItem(value: 'b', label: 'B'),
            ],
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppDropdown<String>));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-dropdown-panel'))).width,
      220,
    );
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(picked, 'b');
  });

  testWidgets('dropdown opens a 220-wide panel, selects and closes', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(_host(_dropdown(onChanged: (v) => picked = v)));
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(_panelKey)), const Size(220, 86));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-dropdown-item-a'))).height,
      36,
    );

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();

    expect(picked, 'b');
    expect(find.byKey(_panelKey), findsNothing);
  });

  testWidgets('escape and an outside tap close the panel', (tester) async {
    await tester.pumpWidget(_host(_dropdown()));

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsNothing);

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsOneWidget);
    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsNothing);
  });

  testWidgets('arrow keys move the highlight and enter selects it', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(_host(_dropdown(onChanged: (v) => picked = v)));

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(picked, 'b');
    expect(find.byKey(_panelKey), findsNothing);
  });

  testWidgets('trigger is a chip-filled 7px radius control with a 14px '
      'chevron and 13/ink label', (tester) async {
    await tester.pumpWidget(_host(_dropdown()));

    final trigger = tester.widget<Container>(find.byKey(_triggerKey));
    final decoration = trigger.decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.light.chip);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.button));
    expect(tester.getSize(find.byKey(_triggerKey)).height, 34);

    final label = tester.widget<Text>(
      find.descendant(of: find.byKey(_triggerKey), matching: find.text('A')),
    );
    expect(label.style!.fontSize, 13);
    expect(label.style!.color, AppPalette.light.ink);

    final chevron = tester.widget<Icon>(find.byKey(_chevronKey));
    expect(chevron.size, 14);
    expect(chevron.icon, LucideIcons.chevronDown);

    await tester.pumpWidget(_host(_dropdown(triggerHeight: 36)));
    expect(tester.getSize(find.byKey(_triggerKey)).height, 36);
  });

  testWidgets('panel flips above the trigger when there is no room below', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 100,
                top: 550,
                width: 160,
                child: AppDropdown<String>(
                  value: 'a',
                  items: const [
                    AppDropdownItem(value: 'a', label: 'A'),
                    AppDropdownItem(value: 'b', label: 'B'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final panelTop = tester.getTopLeft(find.byKey(_panelKey));
    // Two 36px rows + 12px vertical padding + the 1px border on each edge.
    expect(panelTop.dy, 550 - 8 - 86);
    expect(
      tester.getBottomLeft(find.byKey(_panelKey)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(_triggerKey)).dy),
    );
  });

  testWidgets('panel clamps its left edge to the window', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 620,
                top: 100,
                width: 160,
                child: AppDropdown<String>(
                  value: 'a',
                  items: const [
                    AppDropdownItem(value: 'a', label: 'A'),
                    AppDropdownItem(value: 'b', label: 'B'),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    // 800 (test surface) - 8 (edge) - 220 (panel) = 572.
    expect(tester.getTopLeft(find.byKey(_panelKey)).dx, 572);
  });

  testWidgets('coloured items show a 6px dot in the trigger and panel rows', (
    tester,
  ) async {
    const color = Color(0xFF34C759);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 160,
          child: AppDropdown<String>(
            value: 'a',
            items: const [
              AppDropdownItem(value: 'a', label: 'A', color: color),
              AppDropdownItem(value: 'b', label: 'B'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final triggerDot = find.byKey(const ValueKey('app-dropdown-trigger-dot'));
    expect(triggerDot, findsOneWidget);
    expect(tester.getSize(triggerDot), const Size(6, 6));

    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final rowDot = find.byKey(const ValueKey('app-dropdown-dot-a'));
    expect(rowDot, findsOneWidget);
    expect(tester.getSize(rowDot), const Size(6, 6));
    final decoration =
        tester.widget<Container>(rowDot).decoration! as BoxDecoration;
    expect(decoration.color, color);
    expect(decoration.shape, BoxShape.circle);
    expect(
      tester
              .getRect(
                find.descendant(
                  of: find.byKey(_panelKey),
                  matching: find.text('A'),
                ),
              )
              .left -
          tester.getRect(rowDot).right,
      8,
    );
    expect(find.byKey(const ValueKey('app-dropdown-dot-b')), findsNothing);
  });

  testWidgets('hovering a visible row does not scroll the panel', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 30; i++)
        AppDropdownItem(value: 'v$i', label: 'Item $i'),
    ];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 160,
          child: AppDropdown<String>(
            value: 'v0',
            items: items,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final panel = find.byKey(_panelKey);
    final position = tester
        .state<ScrollableState>(
          find.descendant(of: panel, matching: find.byType(Scrollable)),
        )
        .position;
    expect(position.pixels, 0);

    // Row 12 sits well inside the visible part of the capped panel; hover
    // must only highlight it, not centre it (which would scroll the list).
    final row = find.byKey(const ValueKey('app-dropdown-item-v12'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(row));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(position.pixels, 0);
    // The hover still marks the row active.
    final fill = tester.widget<AnimatedContainer>(
      find.descendant(of: row, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (fill.decoration! as BoxDecoration).color,
      isNot(Colors.transparent),
    );
  });

  testWidgets('arrow keys keep the active row inside a short panel', (
    tester,
  ) async {
    final items = [
      for (var i = 0; i < 30; i++)
        AppDropdownItem(value: 'v$i', label: 'Item $i'),
    ];
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 160,
          child: AppDropdown<String>(
            value: 'v0',
            items: items,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final panel = find.byKey(_panelKey);
    // 30 rows do not fit in the 600-high test window, so the list scrolls.
    expect(tester.getSize(panel).height, lessThan(30 * 36));

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final panelRect = tester.getRect(panel);
    final rowRect = tester.getRect(
      find.byKey(const ValueKey('app-dropdown-item-v20')),
    );
    expect(rowRect.top, greaterThanOrEqualTo(panelRect.top));
    expect(rowRect.bottom, lessThanOrEqualTo(panelRect.bottom));
  });

  testWidgets('panel uses card surface, line border and dialog shadow; the '
      'selected row is ink/600 with no checkmark', (tester) async {
    await tester.pumpWidget(_host(_dropdown()));
    await tester.tap(find.byKey(_triggerKey));
    await tester.pumpAndSettle();

    final panel = find.byKey(_panelKey);
    final decoration =
        tester.widget<Container>(panel).decoration! as BoxDecoration;
    expect(decoration.color, AppPalette.light.card);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.card));
    expect(decoration.border, Border.all(color: AppPalette.light.line));
    expect(decoration.boxShadow, kDialogShadow);

    final selected = tester.widget<Text>(
      find.descendant(of: panel, matching: find.text('A')),
    );
    expect(selected.style!.fontWeight, FontWeight.w600);
    expect(selected.style!.color, AppPalette.light.ink);
    final other = tester.widget<Text>(
      find.descendant(of: panel, matching: find.text('B')),
    );
    expect(other.style!.fontWeight, FontWeight.w400);

    expect(
      find.descendant(of: panel, matching: find.byIcon(LucideIcons.check)),
      findsNothing,
    );
  });
}
