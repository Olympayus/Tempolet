import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/theme_controller.dart';
import 'accent_picker.dart';
import 'desktop_prefs.dart';
import '../../desktop/window_service.dart';
import 'notification_prefs.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final offset = ref.watch(defaultReminderOffsetProvider);
    final sound = ref.watch(notificationSoundEnabledProvider);
    final overdueSummary = ref.watch(overdueSummaryEnabledProvider);
    final minimizeToTray = ref.watch(minimizeToTrayEnabledProvider);
    final launchAtStartup = ref.watch(launchAtStartupEnabledProvider);

    final languageValue = locale?.languageCode ?? 'system';

    return Scaffold(
      key: const ValueKey('settings-page'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _Section(
            title: l10n.settingsAppearance,
            children: [
              _LabeledRow(
                label: l10n.themeMode,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.light, label: Text(l10n.themeLight)),
                    ButtonSegment(
                        value: ThemeMode.dark, label: Text(l10n.themeDark)),
                    ButtonSegment(
                        value: ThemeMode.system, label: Text(l10n.themeSystem)),
                  ],
                  selected: {theme.mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(themeControllerProvider.notifier)
                      .setMode(selection.first),
                ),
              ),
              _LabeledRow(
                label: l10n.accentColor,
                child: AccentPicker(
                  selected: theme.accent,
                  onSelected: (color) => ref
                      .read(themeControllerProvider.notifier)
                      .setAccent(color),
                ),
              ),
              _LabeledRow(
                label: l10n.language,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'system', label: Text(l10n.languageSystem)),
                    ButtonSegment(value: 'en', label: const Text('English')),
                    ButtonSegment(value: 'zh', label: const Text('中文')),
                  ],
                  selected: {languageValue},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    ref.read(localeControllerProvider.notifier).setLocale(
                          value == 'system' ? null : Locale(value),
                        );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.settingsNotifications,
            children: [
              _LabeledRow(
                label: l10n.defaultRemindOffset,
                child: SegmentedButton<int?>(
                  segments: [
                    ButtonSegment(
                        value: null, label: Text(l10n.remindNone)),
                    for (final minutes in const [5, 10, 30])
                      ButtonSegment(
                        value: minutes,
                        label: Text(l10n.remindMinutesBefore(minutes)),
                      ),
                  ],
                  selected: {offset},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => ref
                      .read(defaultReminderOffsetProvider.notifier)
                      .set(selection.first),
                ),
              ),
              SwitchListTile(
                key: const ValueKey('switch-sound'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.notificationSound),
                value: sound,
                onChanged: (value) =>
                    ref.read(notificationSoundEnabledProvider.notifier).set(value),
              ),
              SwitchListTile(
                key: const ValueKey('switch-overdue'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.overdueSummary),
                value: overdueSummary,
                onChanged: (value) =>
                    ref.read(overdueSummaryEnabledProvider.notifier).set(value),
              ),
              Text(
                l10n.notificationsRequireAppOpen,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: l10n.settingsDesktop,
            children: [
              SwitchListTile(
                key: const ValueKey('switch-tray'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.closeToTray),
                value: minimizeToTray,
                onChanged: (value) =>
                    ref.read(minimizeToTrayEnabledProvider.notifier).set(value),
              ),
              SwitchListTile(
                key: const ValueKey('switch-startup'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.launchAtStartup),
                value: launchAtStartup,
                onChanged: (value) {
                  ref.read(launchAtStartupEnabledProvider.notifier).set(value);
                  syncLaunchAtStartup(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ],
      ),
    );
  }
}
