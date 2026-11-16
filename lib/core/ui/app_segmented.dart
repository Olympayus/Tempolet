import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Desktop compact segmented-control height (`05-components.md` §2).
const double _segmentHeight = 28;

/// Track inset that leaves a 22px inner item.
const EdgeInsets _segmentTrackPadding = EdgeInsets.all(3);

/// Item side padding (`05-components.md` §2).
const EdgeInsets _segmentItemPadding = EdgeInsets.symmetric(horizontal: 12);

const Duration _segmentAnimation = Duration(milliseconds: 120);

const double _hairline = 1;

/// Desktop compact segmented control (`docs/design/05-components.md` §2).
///
/// A chip-filled 28px track with equal-width items; the selected item is a
/// white capsule with a 1px `lineStrong` border and a 1px top highlight.
/// Interaction is deliberately Material-free: [MouseRegion] + [GestureDetector].
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.values,
    required this.labelFor,
    required this.selected,
    required this.onChanged,
    this.height = _segmentHeight,
  });

  final List<T> values;
  final Widget Function(T value) labelFor;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.chip,
          borderRadius: BorderRadius.circular(AppRadii.segment),
        ),
        child: Padding(
          padding: _segmentTrackPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final value in values)
                Expanded(
                  child: _SegmentItem(
                    label: labelFor(value),
                    selected: value == selected,
                    onTap: () => onChanged(value),
                    palette: palette,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.button);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedContainer(
                duration: _segmentAnimation,
                curve: Curves.easeOut,
                alignment: Alignment.center,
                padding: _segmentItemPadding,
                decoration: selected
                    ? BoxDecoration(
                        // The "white" selected cap: `card` stays a raised
                        // surface in dark mode, unlike `bg`.
                        color: palette.card,
                        borderRadius: radius,
                        border: Border.all(
                          color: palette.lineStrong,
                          width: _hairline,
                        ),
                      )
                    : null,
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
              if (selected)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(height: _hairline, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}
