import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_info.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/platform/android_capabilities.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/ui/app_dropdown.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/ui/app_switch.dart';
import '../../desktop/file_reveal.dart';
import '../../desktop/window_service.dart';
import '../events/fields/lead_field.dart';
import 'accent_picker.dart';
import 'desktop_prefs.dart';
import 'notification_prefs.dart';

/// Grouped settings page (`docs/design/10-ui-refinement.md` §8).
///
/// One 760-wide column: an appearance, notifications, desktop and about card,
/// each with 64-high two-part rows and right-aligned self-drawn controls.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = _paletteOf(context);
    final layout = resolveAppLayout(context);
    final desktop = layout == AppLayout.desktop;
    final phone = layout == AppLayout.phone;
    final theme = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final offset = ref.watch(defaultReminderOffsetProvider);
    final sound = ref.watch(notificationSoundEnabledProvider);
    final overdueSummary = ref.watch(overdueSummaryEnabledProvider);
    final permission = ref.watch(notificationPermissionProvider).value;
    final exactAlarm = ref.watch(exactAlarmAvailableProvider).value;
    final minimizeToTray = ref.watch(minimizeToTrayEnabledProvider);
    final launchAtStartup = ref.watch(launchAtStartupEnabledProvider);

    final languageValue = locale?.languageCode ?? 'system';

    Future<void> pickAccent() async {
      final picked = await showAccentColorPicker(
        context,
        initial: theme.accent,
      );
      if (picked != null) {
        ref.read(themeControllerProvider.notifier).setAccent(picked);
      }
    }

    return Scaffold(
      key: const ValueKey('settings-page'),
      backgroundColor: palette.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(phone ? 16 : 32, 24, phone ? 16 : 32, 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            key: const ValueKey('settings-content'),
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.navSettings,
                  style: AppTextStyles.display.copyWith(
                    fontSize: phone ? 34 : 28,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 24),
                _SettingsGroup(
                  containerKey: const ValueKey('settings-group-appearance'),
                  palette: palette,
                  label: l10n.settingsAppearance,
                  rows: [
                    _SettingsRow(
                      key: const ValueKey('settings-row-theme'),
                      palette: palette,
                      title: l10n.themeMode,
                      control: AppSegmented<ThemeMode>(
                        key: const ValueKey('theme-segmented'),
                        values: const [
                          ThemeMode.light,
                          ThemeMode.dark,
                          ThemeMode.system,
                        ],
                        selected: theme.mode,
                        labelFor: (value) =>
                            _themeLabel(value, theme.mode, palette, l10n),
                        onChanged: (mode) => ref
                            .read(themeControllerProvider.notifier)
                            .setMode(mode),
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('settings-row-accent'),
                      palette: palette,
                      title: l10n.accentColor,
                      hint: l10n.accentHint,
                      onTap: pickAccent,
                      control: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AccentSwatch(
                            key: const ValueKey('accent-swatch'),
                            color: theme.accent,
                            onTap: pickAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _hexOf(theme.accent),
                            style: AppTextStyles.body.copyWith(
                              color: palette.sub,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: palette.sub,
                          ),
                        ],
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('settings-row-language'),
                      palette: palette,
                      title: l10n.language,
                      control: SizedBox(
                        width: 160,
                        child: AppDropdown<String>(
                          key: const ValueKey('language-dropdown'),
                          value: languageValue,
                          triggerHeight: 36,
                          semanticLabel: l10n.language,
                          items: [
                            AppDropdownItem(
                              value: 'system',
                              label: l10n.languageSystem,
                            ),
                            const AppDropdownItem(value: 'zh', label: '中文'),
                            const AppDropdownItem(
                              value: 'en',
                              label: 'English',
                            ),
                          ],
                          onChanged: (value) {
                            ref
                                .read(localeControllerProvider.notifier)
                                .setLocale(
                                  value == 'system' ? null : Locale(value),
                                );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsGroup(
                  containerKey: const ValueKey('settings-group-notifications'),
                  palette: palette,
                  label: l10n.settingsNotifications,
                  rows: [
                    if (desktop)
                      _SettingsNoteRow(
                        key: const ValueKey('settings-row-windows-note'),
                        palette: palette,
                        text: l10n.notificationsWindowsNote,
                      ),
                    _SettingsRow(
                      key: const ValueKey('settings-row-lead'),
                      palette: palette,
                      title: l10n.defaultRemindOffset,
                      hint: l10n.defaultRemindHint,
                      control: SizedBox(
                        width: 160,
                        child: LeadField(
                          value: offset,
                          triggerHeight: 36,
                          onChanged: (next) => ref
                              .read(defaultReminderOffsetProvider.notifier)
                              .set(next),
                        ),
                      ),
                    ),
                    if (!desktop &&
                        permission != null &&
                        permission != NotificationPermissionState.granted)
                      _AndroidCapabilityRow(
                        key: const ValueKey(
                          'settings-row-notification-permission',
                        ),
                        palette: palette,
                        title: l10n.notificationPermission,
                        text:
                            permission ==
                                NotificationPermissionState.permanentlyDenied
                            ? l10n.notificationClosedBySystem
                            : l10n.notificationOff,
                        action: l10n.openSystemSettings,
                        danger: true,
                        onTap: () => ref
                            .read(androidCapabilitiesProvider)
                            .openNotificationSettings(),
                      ),
                    if (!desktop && exactAlarm == false)
                      _AndroidCapabilityRow(
                        key: const ValueKey('settings-row-exact-alarm'),
                        palette: palette,
                        title: l10n.exactAlarmTitle,
                        text: l10n.exactAlarmHint,
                        action: l10n.openSystemSettings,
                        onTap: () => ref
                            .read(androidCapabilitiesProvider)
                            .openExactAlarmSettings(),
                      ),
                    _SettingsRow(
                      key: const ValueKey('settings-row-sound'),
                      palette: palette,
                      title: l10n.notificationSound,
                      onTap: () => ref
                          .read(notificationSoundEnabledProvider.notifier)
                          .set(!sound),
                      control: AppSwitch(
                        key: const ValueKey('switch-sound'),
                        value: sound,
                        onChanged: (value) => ref
                            .read(notificationSoundEnabledProvider.notifier)
                            .set(value),
                      ),
                    ),
                    _SettingsRow(
                      key: const ValueKey('settings-row-overdue'),
                      palette: palette,
                      title: l10n.overdueSummary,
                      hint: l10n.overdueSummaryHint,
                      onTap: () => ref
                          .read(overdueSummaryEnabledProvider.notifier)
                          .set(!overdueSummary),
                      control: AppSwitch(
                        key: const ValueKey('switch-overdue'),
                        value: overdueSummary,
                        onChanged: (value) => ref
                            .read(overdueSummaryEnabledProvider.notifier)
                            .set(value),
                      ),
                    ),
                  ],
                ),
                if (desktop) ...[
                  const SizedBox(height: 28),
                  _SettingsGroup(
                    containerKey: const ValueKey('settings-group-desktop'),
                    palette: palette,
                    label: l10n.settingsDesktop,
                    rows: [
                      _SettingsRow(
                        key: const ValueKey('settings-row-tray'),
                        palette: palette,
                        title: l10n.closeToTray,
                        hint: l10n.closeToTrayHint,
                        onTap: () => ref
                            .read(minimizeToTrayEnabledProvider.notifier)
                            .set(!minimizeToTray),
                        control: AppSwitch(
                          key: const ValueKey('switch-tray'),
                          value: minimizeToTray,
                          onChanged: (value) => ref
                              .read(minimizeToTrayEnabledProvider.notifier)
                              .set(value),
                        ),
                      ),
                      _SettingsRow(
                        key: const ValueKey('settings-row-startup'),
                        palette: palette,
                        title: l10n.launchAtStartup,
                        hint: l10n.launchAtStartupHint,
                        onTap: () {
                          final value = !launchAtStartup;
                          ref
                              .read(launchAtStartupEnabledProvider.notifier)
                              .set(value);
                          syncLaunchAtStartup(value);
                        },
                        control: AppSwitch(
                          key: const ValueKey('switch-startup'),
                          value: launchAtStartup,
                          onChanged: (value) {
                            ref
                                .read(launchAtStartupEnabledProvider.notifier)
                                .set(value);
                            syncLaunchAtStartup(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                _SettingsGroup(
                  containerKey: const ValueKey('settings-group-about'),
                  palette: palette,
                  label: l10n.about,
                  rows: [
                    _SettingsRow(
                      key: const ValueKey('settings-row-version'),
                      palette: palette,
                      title: l10n.version,
                      control: Text(
                        kAppVersion,
                        style: AppTextStyles.body.copyWith(color: palette.sub),
                      ),
                    ),
                    if (desktop)
                      _SettingsRow(
                        key: const ValueKey('settings-row-data'),
                        palette: palette,
                        title: l10n.dataLocation,
                        control: _TextLink(
                          key: const ValueKey('open-data-folder'),
                          label: l10n.openFolder,
                          color: palette.accent,
                          onTap: openDataFolder,
                        ),
                      ),
                  ],
                ),
              ],
            ),
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

String _hexOf(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Widget _themeLabel(
  ThemeMode value,
  ThemeMode selected,
  AppPalette palette,
  AppLocalizations l10n,
) {
  final (icon, label) = switch (value) {
    ThemeMode.light => (LucideIcons.sun, l10n.themeLight),
    ThemeMode.dark => (LucideIcons.moon, l10n.themeDark),
    ThemeMode.system => (LucideIcons.monitor, l10n.themeSystem),
  };
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 14,
        color: value == selected ? palette.ink : palette.sub,
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

/// A rounded card grouping settings rows with 1px separators between them.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.containerKey,
    required this.palette,
    required this.label,
    required this.rows,
  });

  final Key containerKey;
  final AppPalette palette;
  final String label;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const AppHairline());
      children.add(rows[i]);
    }

    final radius = BorderRadius.circular(AppRadii.group);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label,
            style: AppTextStyles.section.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: containerKey,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: radius,
            border: Border.all(color: palette.line),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// A two-part settings row: 14/500 title + optional 13/`sub` hint on the
/// left, right-aligned control on the right, at least 64 high.
class _SettingsRow extends StatefulWidget {
  const _SettingsRow({
    super.key,
    required this.palette,
    required this.title,
    this.hint,
    required this.control,
    this.onTap,
  });

  final AppPalette palette;
  final String title;
  final String? hint;
  final Widget control;
  final VoidCallback? onTap;

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final interactive = widget.onTap != null;
    // Touch phone rows put segmented controls on their own line, stretched
    // (`10-ui-refinement.md` §9.10).
    final stacked =
        resolveAppLayout(context) == AppLayout.phone &&
        widget.control is AppSegmented;

    final textColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: AppTextStyles.rowTitle.copyWith(color: palette.ink),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.hint!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.hint.copyWith(color: palette.sub),
          ),
        ],
      ],
    );

    final content = Container(
      constraints: const BoxConstraints(minHeight: AppSizes.rowTall),
      // Inset the hover fill on all four sides so it never paints over the
      // group card's 1px border, including the first/last row's top/bottom.
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: interactive && _hovered ? palette.hover : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [textColumn, const SizedBox(height: 8), widget.control],
            )
          : Row(
              children: [
                Expanded(child: textColumn),
                const SizedBox(width: 24),
                widget.control,
              ],
            ),
    );

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: interactive
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: content,
            )
          : content,
    );
  }
}

/// Android capability row: title plus a 13px explanatory line (danger for a
/// denied notification permission) and a right-aligned system-settings link.
class _AndroidCapabilityRow extends StatelessWidget {
  const _AndroidCapabilityRow({
    super.key,
    required this.palette,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
    this.danger = false,
  });

  final AppPalette palette;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(color: palette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: danger ? palette.danger : palette.sub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _TextLink(label: action, color: palette.accent, onTap: onTap),
        ],
      ),
    );
  }
}

/// Permanent, non-tappable Windows notification explanation row.
class _SettingsNoteRow extends StatelessWidget {
  const _SettingsNoteRow({
    super.key,
    required this.palette,
    required this.text,
  });

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.caption.copyWith(color: palette.sub),
      ),
    );
  }
}

/// Inline 13/`accent` text link with no underline and no Material chrome.
class _TextLink extends StatelessWidget {
  const _TextLink({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(label, style: AppTextStyles.body.copyWith(color: color)),
      ),
    );
  }
}
