import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_icons.dart';

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

    return Container(
      key: const ValueKey('icon-rail'),
      width: kRailWidth,
      decoration: BoxDecoration(
        color: p.rail,
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _railVerticalPadding),
        child: Column(
          children: [
            _RailDestination(
              key: const ValueKey('rail-calendar'),
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
              key: const ValueKey('rail-reminders'),
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
              key: const ValueKey('rail-settings'),
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
    super.key,
    required this.icon,
    required this.label,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

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
        color: selected ? palette.accentTint : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          hoverColor: palette.hover,
          onTap: onTap,
          child: SizedBox(
            width: _destinationSize,
            height: _destinationSize,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}
