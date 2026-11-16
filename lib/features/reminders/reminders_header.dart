import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_icons.dart';

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
  });

  final VoidCallback? onManageCategories;
  final VoidCallback onViewCompleted;
  final VoidCallback onCreate;

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
              child: Text(
                l10n.remindersTitle,
                key: const ValueKey('reminders-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.display.copyWith(color: palette.ink),
              ),
            ),
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
              leadingIcon: const AppIcon.plus(
                size: 16,
                color: Colors.white,
              ),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}
