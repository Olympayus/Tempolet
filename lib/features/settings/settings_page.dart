import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../desktop/file_reveal.dart';
import '../../desktop/window_service.dart';
import '../events/fields/lead_field.dart';
import 'accent_picker.dart';
import 'desktop_prefs.dart';
import 'notification_prefs.dart';

/// Grouped settings page: appearance, notifications, desktop and about.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = _paletteOf(context);
    final theme = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final offset = ref.watch(defaultReminderOffsetProvider);
    final sound = ref.watch(notificationSoundEnabledProvider);
    final overdueSummary = ref.watch(overdueSummaryEnabledProvider);
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
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.navSettings,
                  style: AppTextStyles.display.copyWith(color: palette.ink),
                ),
                const SizedBox(height: 18),
                _SettingsGroup(
                  palette: palette,
                  label: l10n.settingsAppearance,
                  children: [
                    _SettingsRow(
                      palette: palette,
                      label: l10n.themeMode,
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text(l10n.themeLight),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text(l10n.themeDark),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text(l10n.themeSystem),
                          ),
                        ],
                        selected: {theme.mode},
                        showSelectedIcon: false,
                        style: SegmentedButton.styleFrom(
                          textStyle: AppTextStyles.secondary,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: palette.sub,
                          selectedForegroundColor: palette.ink,
                          selectedBackgroundColor: palette.chip,
                        ),
                        onSelectionChanged: (selection) => ref
                            .read(themeControllerProvider.notifier)
                            .setMode(selection.first),
                      ),
                    ),
                    _SettingsRow(
                      palette: palette,
                      label: l10n.accentColor,
                      child: AccentSwatch(
                        key: const ValueKey('accent-swatch'),
                        color: theme.accent,
                        onTap: pickAccent,
                      ),
                    ),
                    _SettingsRow(
                      palette: palette,
                      label: l10n.language,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          key: const ValueKey('language-dropdown'),
                          value: languageValue,
                          isDense: true,
                          dropdownColor: palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.field),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: palette.sub,
                          ),
                          style: AppTextStyles.body.copyWith(
                            color: palette.ink,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'system',
                              child: Text(l10n.languageSystem),
                            ),
                            const DropdownMenuItem(
                              value: 'zh',
                              child: Text('中文'),
                            ),
                            const DropdownMenuItem(
                              value: 'en',
                              child: Text('English'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
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
                const SizedBox(height: 16),
                _SettingsGroup(
                  palette: palette,
                  label: l10n.settingsNotifications,
                  children: [
                    _SettingsRow(
                      palette: palette,
                      label: l10n.defaultRemindOffset,
                      child: SizedBox(
                        width: 180,
                        child: LeadField(
                          value: offset,
                          onChanged: (next) => ref
                              .read(defaultReminderOffsetProvider.notifier)
                              .set(next),
                        ),
                      ),
                    ),
                    _SwitchRow(
                      key: const ValueKey('switch-sound'),
                      palette: palette,
                      label: l10n.notificationSound,
                      value: sound,
                      onChanged: (value) => ref
                          .read(notificationSoundEnabledProvider.notifier)
                          .set(value),
                    ),
                    _SwitchRow(
                      key: const ValueKey('switch-overdue'),
                      palette: palette,
                      label: l10n.overdueSummary,
                      value: overdueSummary,
                      onChanged: (value) => ref
                          .read(overdueSummaryEnabledProvider.notifier)
                          .set(value),
                    ),
                    _Footnote(
                      palette: palette,
                      text: l10n.notificationsRequireAppOpen,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  palette: palette,
                  label: l10n.settingsDesktop,
                  children: [
                    _SwitchRow(
                      key: const ValueKey('switch-tray'),
                      palette: palette,
                      label: l10n.closeToTray,
                      value: minimizeToTray,
                      onChanged: (value) => ref
                          .read(minimizeToTrayEnabledProvider.notifier)
                          .set(value),
                    ),
                    _SwitchRow(
                      key: const ValueKey('switch-startup'),
                      palette: palette,
                      label: l10n.launchAtStartup,
                      value: launchAtStartup,
                      onChanged: (value) {
                        ref
                            .read(launchAtStartupEnabledProvider.notifier)
                            .set(value);
                        syncLaunchAtStartup(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  palette: palette,
                  label: l10n.about,
                  children: [
                    _SettingsRow(
                      palette: palette,
                      label: l10n.version,
                      child: Text(
                        kAppVersion,
                        style: AppTextStyles.body.copyWith(color: palette.sub),
                      ),
                    ),
                    _SettingsRow(
                      palette: palette,
                      label: l10n.dataLocation,
                      child: TextButton(
                        key: const ValueKey('open-data-folder'),
                        onPressed: openDataFolder,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                          textStyle: AppTextStyles.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.openFolder),
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

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.palette,
    required this.label,
    required this.children,
  });

  final AppPalette palette;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: palette.line));
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: palette.sub),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: palette.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.card),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.palette,
    required this.label,
    required this.child,
  });

  final AppPalette palette;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: palette.ink),
              ),
            ),
            const SizedBox(width: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final AppPalette palette;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 36),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: palette.ink),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.palette, required this.text});

  final AppPalette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(color: palette.sub),
      ),
    );
  }
}
