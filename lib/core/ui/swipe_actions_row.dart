import 'package:flutter/material.dart';

/// Width of one revealed action button (`10-ui-refinement.md` §9.14).
const double kSwipeActionWidth = 64;

/// How far the row must travel before the release settles it open.
const double _openThreshold = 32;

/// Horizontal travel before the gesture claims the pointer; below this the
/// pointer still belongs to the vertical scrollable or the row's own tap.
const double _axisLock = 8;

/// One-shot open state for a list's swipe rows: at most one row is open.
class SwipeActionsController extends ChangeNotifier {
  Object? _openId;

  /// The id of the row currently revealing its actions, if any.
  Object? get openId => _openId;

  /// Opens [id], closing whichever row was open before it.
  void open(Object id) {
    if (_openId == id) return;
    _openId = id;
    notifyListeners();
  }

  /// Closes the open row, if any.
  void close() {
    if (_openId == null) return;
    _openId = null;
    notifyListeners();
  }
}

/// One action revealed behind a swiped row.
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.color,
    required this.onPressed,
    this.id,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  /// Stable key segment; defaults to [label]. Use it when the label is
  /// localized and a stable `swipe-action-<row>-<id>` key is needed.
  final String? id;

  String get keySegment => id ?? label;
}

/// A list row that reveals [actions] when swiped left.
///
/// The row is axis-locked: the first [axisLock] of travel decide between the
/// horizontal reveal and the enclosing vertical scrollable. Releasing past
/// [_openThreshold] opens the row through [controller], which enforces one
/// open row per list. While open, an opaque layer absorbs taps so a swipe
/// never doubles as a row tap, and tapping the row closes it.
class SwipeActionsRow extends StatefulWidget {
  const SwipeActionsRow({
    super.key,
    required this.id,
    required this.controller,
    required this.actions,
    required this.child,
    this.enabled = true,
  });

  final Object id;
  final SwipeActionsController controller;
  final List<SwipeAction> actions;
  final Widget child;
  final bool enabled;

  @override
  State<SwipeActionsRow> createState() => _SwipeActionsRowState();
}

class _SwipeActionsRowState extends State<SwipeActionsRow> {
  double _dragDx = 0;
  bool _dragging = false;

  bool get _open => widget.controller.openId == widget.id;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(SwipeActionsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onDragStart(DragStartDetails details) {
    _dragDx = 0;
    _dragging = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    if (!_dragging && _dragDx.abs() >= _axisLock) _dragging = true;
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dragDx <= -_openThreshold || velocity <= -150) {
      widget.controller.open(widget.id);
    } else {
      widget.controller.close();
    }
    _dragging = false;
    _dragDx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    final enabled = widget.enabled;
    final content = GestureDetector(
      key: ValueKey('swipe-row-${widget.id}'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: enabled ? _onDragStart : null,
      onHorizontalDragUpdate: enabled ? _onDragUpdate : null,
      onHorizontalDragEnd: enabled ? _onDragEnd : null,
      child: widget.child,
    );

    return ClipRect(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _open ? 1 : 0),
        duration: duration,
        curve: Curves.easeOut,
        builder: (context, progress, child) {
          final reveal = progress > 0;
          final actionsWidth = kSwipeActionWidth * widget.actions.length;
          return Stack(
            children: [
              child!,
              if (reveal)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: -actionsWidth * (1 - progress),
                  width: actionsWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final action in widget.actions)
                        SizedBox(
                          width: kSwipeActionWidth,
                          child: GestureDetector(
                            key: ValueKey(
                              'swipe-action-${widget.id}-${action.keySegment}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              widget.controller.close();
                              action.onPressed();
                            },
                            child: ColoredBox(
                              color: action.color,
                              child: Center(
                                child: Text(
                                  action.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              // The leading completion circle stays tappable while the row is
              // open; the rest of the content closes the row on tap.
              if (reveal)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 48,
                  right: actionsWidth * progress,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.controller.close,
                  ),
                ),
            ],
          );
        },
        child: content,
      ),
    );
  }
}
