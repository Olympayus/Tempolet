import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_icons.dart';

/// Height of the floating dock itself (`02-shell-mobile.md` §1).
const double kPhoneDockHeight = 48;

/// Horizontal inset from the screen edges.
const double kPhoneDockInset = 16;

/// Bottom gap between the dock and the safe area.
const double kPhoneDockBottomGap = 12;

/// Extra bottom padding pages need so their last row clears the floating dock.
const double kPhoneDockClearance =
    kPhoneDockHeight + kPhoneDockBottomGap + 12;

/// Selected item pill (`02-shell-mobile.md` §1: 36×31, tinted).
const double _selectedWidth = 36;
const double _selectedHeight = 31;

/// Muse-style floating pill dock: three destinations, no labels, the selected
/// item carries an `accentTint` pill (`docs/design/02-shell-mobile.md` §1).
class PhoneDock extends StatelessWidget {
  const PhoneDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('phone-dock'),
      height: kPhoneDockHeight,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(kPhoneDockHeight / 2),
        border: Border.all(color: p.line),
        boxShadow: kCardShadow,
      ),
      child: Row(
        children: [
          _DockDestination(
            key: const ValueKey('dock-calendar'),
            label: l10n.navCalendar,
            selected: selectedIndex == 0,
            palette: p,
            onTap: () => onSelected(0),
            icon: AppIcon.calendar(
              size: 20,
              color: selectedIndex == 0 ? p.accent : p.sub,
            ),
          ),
          _DockDestination(
            key: const ValueKey('dock-reminders'),
            label: l10n.navReminders,
            selected: selectedIndex == 1,
            palette: p,
            onTap: () => onSelected(1),
            icon: AppIcon.bell(
              size: 20,
              color: selectedIndex == 1 ? p.accent : p.sub,
            ),
          ),
          _DockDestination(
            key: const ValueKey('dock-settings'),
            label: l10n.navSettings,
            selected: selectedIndex == 2,
            palette: p,
            onTap: () => onSelected(2),
            icon: AppIcon.settings(
              size: 20,
              color: selectedIndex == 2 ? p.accent : p.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockDestination extends StatelessWidget {
  const _DockDestination({
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: _selectedWidth,
              height: _selectedHeight,
              decoration: BoxDecoration(
                color: selected ? palette.accentTint : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
