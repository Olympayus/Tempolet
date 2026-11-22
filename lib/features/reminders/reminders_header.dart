import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/fitted_label.dart';

/// 64px page header for `/reminders` (`10-ui-refinement.md` §9.7).
///
/// The title carries no count; the right side is two quiet icon buttons
/// (categories, completed) followed by the page's single solid primary button.
class RemindersHeader extends StatelessWidget {
  const RemindersHeader({
    super.key,
    required this.onManageCategories,
    required this.onViewCompleted,
    required this.onCreate,
    this.leftColumnOpen,
    this.onToggleLeftColumn,
  });

  final VoidCallback? onManageCategories;
  final VoidCallback onViewCompleted;
  final VoidCallback onCreate;

  /// Tablet only: whether the left calendar/timeline column is showing.
  final bool? leftColumnOpen;

  /// Tablet only: toggles the left column.
  final VoidCallback? onToggleLeftColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      key: const ValueKey('reminders-header'),
      height: AppSizes.header,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              // Scale down rather than ellipsise (see the phone header).
              child: FittedLabel(
                l10n.remindersTitle,
                key: const ValueKey('reminders-title'),
                alignment: Alignment.centerLeft,
                textAlign: TextAlign.left,
                style: AppTextStyles.display.copyWith(color: palette.ink),
              ),
            ),
            if (onToggleLeftColumn != null) ...[
              AppIconButton(
                key: const ValueKey('reminders-left-toggle'),
                tooltip: leftColumnOpen ?? true
                    ? l10n.hideLeftPanel
                    : l10n.showLeftPanel,
                onPressed: onToggleLeftColumn,
                icon: Icon(
                  leftColumnOpen ?? true
                      ? LucideIcons.panelLeftClose
                      : LucideIcons.panelLeftOpen,
                  size: 18,
                  color: palette.sub,
                ),
              ),
              const SizedBox(width: 8),
            ],
            AppIconButton(
              key: const ValueKey('reminders-manage-categories'),
              tooltip: l10n.manageCategories,
              onPressed: onManageCategories,
              icon: Icon(
                LucideIcons.folderTree,
                size: 18,
                color: onManageCategories == null
                    ? palette.subMuted
                    : palette.sub,
              ),
            ),
            const SizedBox(width: 8),
            AppIconButton(
              key: const ValueKey('reminders-view-completed'),
              tooltip: l10n.viewCompletedShort,
              onPressed: onViewCompleted,
              icon: Icon(LucideIcons.circleCheck, size: 18, color: palette.sub),
            ),
            const SizedBox(width: 12),
            AppButton.primary(
              key: const ValueKey('reminders-new'),
              label: l10n.newItem,
              leadingIcon: const AppIcon.plus(size: 16, color: Colors.white),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}
