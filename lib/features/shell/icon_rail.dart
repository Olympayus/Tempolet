import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/layout_metrics.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/touch_target.dart';

/// Fixed width of the icon rail (`docs/design/02-shell-desktop.md` §1,
/// `docs/design/10-ui-refinement.md` §7.1; v0.1.3 widens 54 → 56).
const double kRailWidth = 56;

/// 27×27 destination tile, including the selected `accent-tint` background
/// (`docs/design/02-shell-desktop.md` §2).
const double _destinationSize = 27;

/// Gap between adjacent destinations (`10-ui-refinement.md` §7.1).
const double _destinationGap = 8;

/// Top/bottom inset of the rail (`10-ui-refinement.md` §7.1).
const double _railVerticalPadding = 16;

/// 刻度纸 icon rail: global navigation, 27×27 destinations.
class IconRail extends StatelessWidget {
  const IconRail({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    // Desktop keeps the original 27×27 hit area; touch layouts expand it to
    // 44×44 without changing the visual (`design spec` §8.2).
    final hitSize = isTouchLayout(resolveAppLayout(context))
        ? kMinHitTarget
        : _destinationSize;

    return Container(
      key: const ValueKey('icon-rail'),
      width: kRailWidth,
      decoration: BoxDecoration(
        color: p.nav,
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _railVerticalPadding),
        child: Column(
          children: [
            _RailDestination(
              hitKey: const ValueKey('rail-calendar-hit'),
              visualKey: const ValueKey('rail-calendar'),
              hitSize: hitSize,
              icon: AppIcon.calendar(
                size: 18,
                color: selectedIndex == 0 ? p.accent : p.sub,
              ),
              label: l10n.navCalendar,
              palette: p,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            const SizedBox(height: _destinationGap),
            _RailDestination(
              hitKey: const ValueKey('rail-reminders-hit'),
              visualKey: const ValueKey('rail-reminders'),
              hitSize: hitSize,
              icon: AppIcon.bell(
                size: 18,
                color: selectedIndex == 1 ? p.accent : p.sub,
              ),
              label: l10n.navReminders,
              palette: p,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
            const Spacer(),
            _RailDestination(
              hitKey: const ValueKey('rail-settings-hit'),
              visualKey: const ValueKey('rail-settings'),
              hitSize: hitSize,
              icon: AppIcon.settings(
                size: 18,
                color: selectedIndex == 2 ? p.accent : p.sub,
              ),
              label: l10n.navSettings,
              palette: p,
              selected: selectedIndex == 2,
              onTap: () => onSelected(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.hitKey,
    required this.visualKey,
    required this.hitSize,
    required this.icon,
    required this.label,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final Key hitKey;
  final Key visualKey;
  final double hitSize;
  final Widget icon;
  final String label;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadii.segment);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        // The InkWell wraps the enlarged target, so the whole hit box taps.
        child: InkWell(
          borderRadius: radius,
          hoverColor: palette.hover,
          onTap: onTap,
          child: TouchTarget(
            key: hitKey,
            minSize: hitSize,
            child: Container(
              key: visualKey,
              width: _destinationSize,
              height: _destinationSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.accentTint : Colors.transparent,
                borderRadius: radius,
              ),
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}
