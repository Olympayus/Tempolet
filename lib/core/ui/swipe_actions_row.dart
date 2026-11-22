import 'package:flutter/material.dart';

import 'fitted_label.dart';

/// Width of one revealed action button (`10-ui-refinement.md` §9.14).
const double kSwipeActionWidth = 64;

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

/// A list row that is pushed left to reveal [actions], iOS style.
///
/// The content follows the finger and the action strip stays pinned to the
/// right edge underneath it, so the row reads as one surface sliding aside
/// rather than two buttons appearing in place. The gesture is axis-locked: the
/// first [_axisLock] of travel decide between the horizontal reveal and the
/// enclosing vertical scrollable. Releasing past half the strip (or with
/// leftward velocity) opens the row through [controller], which enforces one
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

class _SwipeActionsRowState extends State<SwipeActionsRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;

  double _dragDx = 0;
  bool _dragging = false;

  bool get _open => widget.controller.openId == widget.id;
  double get _actionsWidth => kSwipeActionWidth * widget.actions.length;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: _open ? 1 : 0,
    );
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slide.duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
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
    _slide.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_open) {
      _slide.animateTo(1, curve: Curves.easeOut);
    } else {
      _slide.animateBack(0, curve: Curves.easeOut);
    }
  }

  /// The content's current offset: settled progress, plus the finger while a
  /// drag is live (clamped so the row can neither over-pull nor move right of
  /// its resting place).
  double get _offset {
    final settled = -_actionsWidth * _slide.value;
    if (!_dragging) return settled;
    return (settled + _dragDx).clamp(-_actionsWidth, 0.0);
  }

  void _onDragStart(DragStartDetails details) {
    _slide.stop();
    _dragDx = 0;
    _dragging = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
    setState(() => _dragging = _dragDx.abs() >= _axisLock);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_dragging) {
      _dragDx = 0;
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final open = _offset <= -_actionsWidth / 2 || velocity <= -150;
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
    if (open) {
      _slide.animateTo(1, curve: Curves.easeOut);
      widget.controller.open(widget.id);
    } else {
      _slide.animateBack(0, curve: Curves.easeOut);
      widget.controller.close();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: AnimatedBuilder(
        animation: _slide,
        builder: (context, child) {
          final offset = _offset;
          final revealed = -offset;
          return Stack(
            children: [
              if (revealed > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: _actionsWidth,
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
                                child: FittedLabel(
                                  action.label,
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
              Transform.translate(offset: Offset(offset, 0), child: child),
              // The row has slid aside, so the whole visible content closes it
              // on tap; the actions keep the strip the content vacated.
              if (revealed > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  right: revealed,
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
