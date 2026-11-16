import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// Fixed width of the icon rail (`docs/design/02-shell-desktop.md` §1).
const double kRailWidth = 54;

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            _RailDestination(
              key: const ValueKey('rail-calendar'),
              icon: LucideIcons.calendar,
              label: l10n.navCalendar,
              palette: p,
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
            const Spacer(),
            _RailDestination(
              key: const ValueKey('rail-settings'),
              icon: LucideIcons.slidersHorizontal,
              label: l10n.navSettings,
              palette: p,
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
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

  final IconData icon;
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
            width: 27,
            height: 27,
            child: Icon(
              icon,
              size: 18,
              color: selected ? palette.accent : palette.sub,
            ),
          ),
        ),
      ),
    );
  }
}
