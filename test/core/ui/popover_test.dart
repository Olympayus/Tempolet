import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/ui/app_popover.dart';

const _contentKey = ValueKey('popover-content');

Widget _host({required Widget child}) => MaterialApp(
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
        child,
      ],
    ),
  ),
);

Rect _globalRect(GlobalKey key) {
  final box = key.currentContext!.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

Widget _content({String label = 'panel', VoidCallback? onTap}) => SizedBox(
  key: _contentKey,
  width: 220,
  height: 100,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Center(child: Text(label)),
  ),
);

void main() {
  testWidgets('popover anchors 8 below the anchor and dismisses on an '
      'outside tap without adding a barrier', (tester) async {
    final hostKey = GlobalKey();
    final anchorKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        child: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              width: 80,
              height: 34,
              child: SizedBox(key: anchorKey),
            ),
            Builder(key: hostKey, builder: (_) => const SizedBox.shrink()),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();
    final barriersBefore = find.byType(ModalBarrier).evaluate().length;

    final future = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(anchorKey),
      builder: (_) => _content(),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_contentKey)), const Offset(100, 142));
    expect(find.byType(ModalBarrier).evaluate().length, barriersBefore);

    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsNothing);
    expect(await future, isNull);
  });

  testWidgets('popover flips above the anchor when there is no room below', (
    tester,
  ) async {
    final hostKey = GlobalKey();
    final anchorKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        child: Stack(
          children: [
            Positioned(
              left: 100,
              top: 520,
              width: 80,
              height: 34,
              child: SizedBox(key: anchorKey),
            ),
            Builder(key: hostKey, builder: (_) => const SizedBox.shrink()),
          ],
        ),
      ),
    );

    final future = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(anchorKey),
      builder: (_) => _content(),
    );
    await tester.pumpAndSettle();

    // 520 (anchor top) - 8 (gap) - 100 (content height).
    expect(tester.getTopLeft(find.byKey(_contentKey)), const Offset(100, 412));

    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets('popover clamps horizontally to the 8px window edge', (
    tester,
  ) async {
    final hostKey = GlobalKey();
    final leftKey = GlobalKey();
    final rightKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 100,
              width: 80,
              height: 34,
              child: SizedBox(key: leftKey),
            ),
            Positioned(
              left: 620,
              top: 100,
              width: 80,
              height: 34,
              child: SizedBox(key: rightKey),
            ),
            Builder(key: hostKey, builder: (_) => const SizedBox.shrink()),
          ],
        ),
      ),
    );

    final leftFuture = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(leftKey),
      builder: (_) => _content(),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_contentKey)).dx, 8);
    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();
    await leftFuture;

    final rightFuture = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(rightKey),
      builder: (_) => _content(),
    );
    await tester.pumpAndSettle();
    // 800 (test surface) - 8 (edge) - 220 (content width) = 572.
    expect(tester.getTopLeft(find.byKey(_contentKey)).dx, 572);
    await tester.tapAt(const Offset(10, 590));
    await tester.pumpAndSettle();
    await rightFuture;
  });

  testWidgets('escape closes the popover', (tester) async {
    final hostKey = GlobalKey();
    final anchorKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        child: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              width: 80,
              height: 34,
              child: SizedBox(key: anchorKey),
            ),
            Builder(key: hostKey, builder: (_) => const SizedBox.shrink()),
          ],
        ),
      ),
    );

    final future = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(anchorKey),
      builder: (_) => _content(),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsNothing);
    expect(await future, isNull);
  });

  testWidgets('popover content can close with a typed result', (tester) async {
    final hostKey = GlobalKey();
    final anchorKey = GlobalKey();
    await tester.pumpWidget(
      _host(
        child: Stack(
          children: [
            Positioned(
              left: 100,
              top: 100,
              width: 80,
              height: 34,
              child: SizedBox(key: anchorKey),
            ),
            Builder(key: hostKey, builder: (_) => const SizedBox.shrink()),
          ],
        ),
      ),
    );

    final future = showAppPopover<String>(
      context: hostKey.currentContext!,
      anchor: _globalRect(anchorKey),
      builder: (context) => _content(
        label: 'pick',
        onTap: () => AppPopoverScope.closeWith<String>(context, 'picked'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('pick'));
    await tester.pumpAndSettle();

    expect(find.byKey(_contentKey), findsNothing);
    expect(await future, 'picked');
  });
}
