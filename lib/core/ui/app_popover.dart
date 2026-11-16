import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gap between the anchor and the popover, and the minimum inset from the
/// window edges (`docs/design/10-ui-refinement.md` §9.13).
const double _popoverGap = 8;
const double _screenEdge = 8;

/// Shows [builder] in an undimmed overlay anchored to [anchor].
///
/// Placement follows the anchored preview popover spec: 8px below the anchor
/// by default, flipped above it when the panel would overflow the bottom edge,
/// and clamped horizontally to the 8px window inset.
///
/// There is no modal barrier: taps and scrolling outside the panel pass
/// through to the app, and a tap outside, Escape, or
/// [AppPopoverScope.closeWith] dismisses it. The returned future completes
/// with the value passed to [AppPopoverScope.closeWith], or `null` when
/// dismissed by a tap or Escape.
///
/// [tapRegionGroupId] is forwarded to the panel's [TapRegion] so a caller can
/// group its trigger with the panel (a tap on the trigger then does not count
/// as an outside tap).
Future<T?> showAppPopover<T>({
  required BuildContext context,
  required Rect anchor,
  required WidgetBuilder builder,
  Object? tapRegionGroupId,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayObject = overlay.context.findRenderObject();
  final overlayOrigin = overlayObject is RenderBox
      ? overlayObject.localToGlobal(Offset.zero)
      : Offset.zero;
  final localAnchor = anchor.shift(-overlayOrigin);

  final completer = Completer<T?>();
  late final OverlayEntry entry;
  var closed = false;

  void close([Object? result]) {
    if (closed) return;
    closed = true;
    if (entry.mounted) {
      entry.remove();
      entry.dispose();
    }
    if (!completer.isCompleted) completer.complete(result as T?);
  }

  entry = OverlayEntry(
    builder: (_) => CustomSingleChildLayout(
      delegate: _AppPopoverLayoutDelegate(anchor: localAnchor),
      child: _AppPopoverHost(
        tapRegionGroupId: tapRegionGroupId,
        onClose: (result) => close(result),
        builder: builder,
      ),
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// Lets popover content dismiss its own popover, optionally with a result.
class AppPopoverScope extends InheritedWidget {
  const AppPopoverScope({super.key, required this.close, required super.child});

  /// Dismisses the popover, completing its future with [result].
  final void Function(Object? result) close;

  /// The nearest popover scope, if any.
  static AppPopoverScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppPopoverScope>();

  /// Dismisses the nearest popover with [result].
  static void closeWith<T>(BuildContext context, [T? result]) {
    maybeOf(context)?.close(result);
  }

  @override
  bool updateShouldNotify(AppPopoverScope oldWidget) => false;
}

/// Positions the panel after measuring it, so any content width/height works.
class _AppPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  _AppPopoverLayoutDelegate({required this.anchor});

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = anchor.bottom + _popoverGap;
    final fitsBelow = below + childSize.height <= size.height - _screenEdge;
    final top = fitsBelow
        ? below
        : math.max(_screenEdge, anchor.top - _popoverGap - childSize.height);
    final maxLeft = size.width - _screenEdge - childSize.width;
    final left = math.max(_screenEdge, math.min(anchor.left, maxLeft));
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AppPopoverLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// Wires outside taps, Escape and the result channel around the popover
/// content.
class _AppPopoverHost extends StatefulWidget {
  const _AppPopoverHost({
    required this.builder,
    required this.onClose,
    this.tapRegionGroupId,
  });

  final WidgetBuilder builder;
  final void Function(Object? result) onClose;
  final Object? tapRegionGroupId;

  @override
  State<_AppPopoverHost> createState() => _AppPopoverHostState();
}

class _AppPopoverHostState extends State<_AppPopoverHost> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AppPopover');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPopoverScope(
      close: widget.onClose,
      child: TapRegion(
        groupId: widget.tapRegionGroupId,
        onTapOutside: (_) => widget.onClose(null),
        child: Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              widget.onClose(null);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(builder: widget.builder),
        ),
      ),
    );
  }
}
