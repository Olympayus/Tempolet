import 'package:flutter/widgets.dart';

import '../layout_metrics.dart';

/// Enlarges a control's interactive footprint to at least [kMinHitTarget]
/// without changing the child's visual size (`design spec` §8.7).
///
/// The target paints nothing; the extra band is transparent. Place the gesture
/// detector *outside* the target so the added band is actually tappable. A
/// child wider than [minSize] keeps its width (segmented controls), and the
/// child is centered inside the resulting box.
class TouchTarget extends StatelessWidget {
  const TouchTarget({
    super.key,
    required this.child,
    this.minSize = kMinHitTarget,
  });

  final Widget child;

  /// Minimum width and height of the hit box.
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      // `widthFactor`/`heightFactor` of 1 make the Align shrink-wrap to the
      // child (instead of filling a loose parent), so the box ends up exactly
      // `max(child, minSize)` on each axis.
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}
