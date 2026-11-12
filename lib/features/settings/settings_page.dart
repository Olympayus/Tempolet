import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';

/// Placeholder — replaced by the real settings page in Task 14.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('settings-page'),
      body: Center(child: Text(AppLocalizations.of(context).navSettings)),
    );
  }
}
