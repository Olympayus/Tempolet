import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/ui/swipe_actions_row.dart';

SwipeAction _editAction() =>
    SwipeAction(label: 'edit', color: Colors.blue, onPressed: () {});

Widget _twoRows(SwipeActionsController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          for (final id in ['a', 'b'])
            SwipeActionsRow(
              id: id,
              controller: controller,
              actions: [_editAction()],
              child: SizedBox(height: 52, child: Text(id)),
            ),
        ],
      ),
    ),
  );
}

Widget _scrollableRow(SwipeActionsController controller) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          SwipeActionsRow(
            id: 'a',
            controller: controller,
            actions: [_editAction()],
            child: const SizedBox(height: 52, child: Text('a')),
          ),
          for (var i = 0; i < 40; i++)
            SizedBox(height: 52, child: Text('filler $i')),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('horizontal drag reveals actions; one row stays open', (
    tester,
  ) async {
    final controller = SwipeActionsController();
    await tester.pumpWidget(_twoRows(controller));

    await tester.drag(
      find.byKey(const ValueKey('swipe-row-a')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swipe-action-a-edit')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('swipe-row-b')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swipe-action-a-edit')), findsNothing);
    expect(find.byKey(const ValueKey('swipe-action-b-edit')), findsOneWidget);
  });

  testWidgets('the row follows the finger while swiping', (tester) async {
    final controller = SwipeActionsController();
    await tester.pumpWidget(_twoRows(controller));

    final row = find.byKey(const ValueKey('swipe-row-a'));
    final restX = tester.getTopLeft(row).dx;

    final gesture = await tester.startGesture(tester.getCenter(row));
    // The first move is eaten by the touch slop; the second one is the drag.
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    // The whole row is pushed aside, not merely covered by the action strip.
    expect(tester.getTopLeft(row).dx, lessThan(restX - 30));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('vertical drag scrolls and does not open', (tester) async {    final controller = SwipeActionsController();
    await tester.pumpWidget(_scrollableRow(controller));

    await tester.drag(
      find.byKey(const ValueKey('swipe-row-a')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swipe-action-a-edit')), findsNothing);
    expect(controller.openId, isNull);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );
  });

  testWidgets('disabled rows ignore the swipe', (tester) async {
    final controller = SwipeActionsController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActionsRow(
            id: 'a',
            controller: controller,
            enabled: false,
            actions: [_editAction()],
            child: const SizedBox(height: 52, child: Text('a')),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('swipe-row-a')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swipe-action-a-edit')), findsNothing);
  });
}
