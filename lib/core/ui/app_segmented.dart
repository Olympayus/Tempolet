import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../layout_metrics.dart';
import '../theme/app_tokens.dart';
import 'touch_target.dart';

/// Track inset that leaves a 22px inner item at the 28px desktop height.
const EdgeInsets _segmentTrackPadding = EdgeInsets.all(3);

/// Item side padding (`05-components.md` §2).
const EdgeInsets _segmentItemPadding = EdgeInsets.symmetric(horizontal: 12);

const Duration _segmentAnimation = Duration(milliseconds: 120);

const double _hairline = 1;

/// Desktop compact segmented control (`docs/design/05-components.md` §2).
///
/// A chip-filled track with equal-width items sized to the longest label
/// (never stretched beyond its content); the selected item is a raised
/// capsule with a 1px `lineStrong` border. The visual height follows
/// [LayoutMetrics.segment] unless [height] overrides it. Safe inside a plain
/// [Row]: it measures its own intrinsic width and never needs a bounded width.
/// Interaction is deliberately Material-free: [MouseRegion] + [GestureDetector].
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.labelFor,
    required this.selected,
    required this.onChanged,
    this.height,
    this.visualKey,
    this.hitKey,
  });

  final List<T> values;
  final Widget Function(T value) labelFor;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Visual track height; defaults to [LayoutMetrics.segment].
  final double? height;

  /// Key for the visual track (height == [height]/[LayoutMetrics.segment]).
  ///
  /// Touch layouts put this on the 36-high track while [hitKey] marks the
  /// surrounding 44-high tappable box, so callers can keep asserting both.
  final Key? visualKey;

  /// Key for the 44-high tappable box created on touch layouts.
  final Key? hitKey;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final segmentHeight = height ?? LayoutMetrics.of(context).segment;
    final trackDecoration = BoxDecoration(
      color: palette.chip,
      borderRadius: BorderRadius.circular(AppRadii.segment),
    );

    // Desktop keeps the original compact track and 27-ish hit area.
    if (!isTouchLayout(resolveAppLayout(context))) {
      return SizedBox(
        key: visualKey,
        height: segmentHeight,
        child: DecoratedBox(
          decoration: trackDecoration,
          child: Padding(
            padding: _segmentTrackPadding,
            child: _EqualWidthItems(
              itemHeight: segmentHeight - _segmentTrackPadding.vertical,
              children: _items(palette),
            ),
          ),
        ),
      );
    }

    // Touch: every item owns the full 44-high band (its GestureDetector is
    // opaque), while the visual track stays [segmentHeight] high and centered.
    // Taps 4px above/below the track therefore still select a segment.
    final hitHeight = math.max(segmentHeight, kMinHitTarget);
    final trackInset = (hitHeight - segmentHeight) / 2;
    final itemHeight = segmentHeight - _segmentTrackPadding.vertical;
    final itemInset = (hitHeight - itemHeight) / 2;
    return TouchTarget(
      key: hitKey,
      child: SizedBox(
        height: hitHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: trackInset,
              bottom: trackInset,
              child: SizedBox(
                key: visualKey,
                height: segmentHeight,
                child: DecoratedBox(decoration: trackDecoration),
              ),
            ),
            _EqualWidthItems(
              itemHeight: hitHeight,
              children: _items(palette, visualInset: itemInset),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _items(AppPalette palette, {double? visualInset}) => [
    for (final value in values)
      _SegmentItem(
        label: labelFor(value),
        selected: value == selected,
        onTap: () => onChanged(value),
        palette: palette,
        visualInset: visualInset,
      ),
  ];
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
    this.visualInset,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  /// Vertical inset that shrinks the painted capsule inside a taller hit box;
  /// null keeps the desktop capsule filling the track.
  final double? visualInset;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.button);
    final Widget visual = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: _segmentAnimation,
            curve: Curves.easeOut,
            alignment: Alignment.center,
            padding: _segmentItemPadding,
            decoration: BoxDecoration(
              // The "white" selected cap: `card` stays a raised
              // surface in dark mode, unlike `bg`.
              color: selected ? palette.card : Colors.transparent,
              borderRadius: radius,
              // Reserve the selected cap's 1px border on every item:
              // an intrinsic-width measure must not depend on which
              // item is selected, or the whole control jumps when the
              // selection moves (design spec §7.1).
              border: Border.all(
                color: selected ? palette.lineStrong : Colors.transparent,
                width: _hairline,
              ),
            ),
            child: DefaultTextStyle(
              style: AppTextStyles.body.copyWith(
                color: selected ? palette.ink : palette.sub,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              child: label,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        shortcuts: _activateShortcuts,
        actions: _activateActions(onTap),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: visualInset == null
                ? visual
                : Padding(
                    padding: EdgeInsets.symmetric(vertical: visualInset!),
                    child: visual,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Enter/Space activate the focused segment.
const Map<ShortcutActivator, Intent> _activateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

Map<Type, Action<Intent>> _activateActions(VoidCallback onTap) => {
  ActivateIntent: CallbackAction<ActivateIntent>(
    onInvoke: (_) {
      onTap();
      return null;
    },
  ),
  ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
    onInvoke: (_) {
      onTap();
      return null;
    },
  ),
};

/// Lays every child out at the same width: the widest child's intrinsic width.
///
/// This keeps the control intrinsic (it never needs a bounded width) while the
/// items stay equal, matching "等宽，以最长项定宽" (design spec §7.1).
class _EqualWidthItems extends MultiChildRenderObjectWidget {
  const _EqualWidthItems({required this.itemHeight, required super.children});

  final double itemHeight;

  @override
  _RenderEqualWidthItems createRenderObject(BuildContext context) =>
      _RenderEqualWidthItems(height: itemHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualWidthItems renderObject,
  ) {
    renderObject.itemHeight = itemHeight;
  }
}

/// Parent data for the equal-width item row.
class _SegmentParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualWidthItems extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SegmentParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SegmentParentData> {
  _RenderEqualWidthItems({required double height}) : _itemHeight = height;

  double _itemHeight;

  set itemHeight(double value) {
    if (_itemHeight == value) return;
    _itemHeight = value;
    markNeedsLayout();
  }

  double _layoutHeight(BoxConstraints constraints) =>
      constraints.hasBoundedHeight ? constraints.maxHeight : _itemHeight;

  /// Widest child measured at [height], clamped when the incoming width is
  /// bounded so a narrow parent shrinks the items instead of overflowing.
  double _widestChild(BoxConstraints constraints, double height) {
    if (childCount == 0) return 0;
    var widest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      widest = math.max(widest, child.getMaxIntrinsicWidth(height));
    }
    if (constraints.hasBoundedWidth) {
      widest = math.min(widest, constraints.maxWidth / childCount);
    }
    return widest;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SegmentParentData) {
      child.parentData = _SegmentParentData();
    }
  }

  @override
  void performLayout() {
    final height = _layoutHeight(constraints);
    final itemWidth = _widestChild(constraints, height);
    var x = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      child.layout(
        BoxConstraints.tightFor(width: itemWidth, height: height),
        parentUsesSize: true,
      );
      (child.parentData! as _SegmentParentData).offset = Offset(x, 0);
      x += itemWidth;
    }
    size = constraints.constrain(Size(x, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final height = _layoutHeight(constraints);
    final itemWidth = _widestChild(constraints, height);
    return constraints.constrain(Size(itemWidth * childCount, height));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      computeMaxIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) {
    final itemHeight = height.isFinite ? height : _itemHeight;
    var widest = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      widest = math.max(widest, child.getMaxIntrinsicWidth(itemHeight));
    }
    return widest * childCount;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _itemHeight;

  @override
  double computeMaxIntrinsicHeight(double width) => _itemHeight;

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}
