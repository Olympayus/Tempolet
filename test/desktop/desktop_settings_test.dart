import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/desktop/file_reveal.dart';
import 'package:tempolet/desktop/window_service.dart';
import 'package:tempolet/features/settings/desktop_prefs.dart';

/// Records which path_provider directory [openDataFolder] resolves.
class _FakePathProvider extends PathProviderPlatform {
  int documentsCalls = 0;
  int supportCalls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    documentsCalls++;
    return 'documents';
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    supportCalls++;
    return 'support';
  }
}

void main() {
  test('shouldHideOnClose follows the minimise-to-tray setting', () {
    expect(shouldHideOnClose(true), isTrue);
    expect(shouldHideOnClose(false), isFalse);
  });

  test('desktop prefs restore from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'minimize_to_tray': false,
      'launch_at_startup': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(minimizeToTrayEnabledProvider), isFalse);
    expect(container.read(launchAtStartupEnabledProvider), isTrue);
  });

  test('desktop prefs default to tray-on, startup-off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(minimizeToTrayEnabledProvider), isTrue);
    expect(container.read(launchAtStartupEnabledProvider), isFalse);
  });

  testWidgets('revealing the data folder is a no-op off desktop', (
    tester,
  ) async {
    var resolved = false;
    var launched = false;
    await openDataFolder(
      platform: TargetPlatform.android,
      resolveFolder: () async {
        resolved = true;
        return Directory('documents');
      },
      launch: (executable, arguments) async {
        launched = true;
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(resolved, isFalse);
    expect(launched, isFalse);
  });

  testWidgets('openDataFolder reveals the resolved folder in Explorer', (
    tester,
  ) async {
    String? executable;
    List<String>? arguments;
    await openDataFolder(
      platform: TargetPlatform.windows,
      resolveFolder: () async => Directory('resolved-data'),
      launch: (exe, args) async {
        executable = exe;
        arguments = args;
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(executable, 'explorer');
    expect(arguments, ['resolved-data']);
  });

  testWidgets('openDataFolder resolves the documents directory by default', (
    tester,
  ) async {
    // The database (drift_flutter) and the note vault both live under the
    // application documents directory, not the support directory.
    final fake = _FakePathProvider();
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = fake;
    addTearDown(() => PathProviderPlatform.instance = previous);

    List<String>? arguments;
    await openDataFolder(
      platform: TargetPlatform.windows,
      launch: (exe, args) async {
        arguments = args;
        return ProcessResult(0, 0, '', '');
      },
    );

    expect(fake.documentsCalls, 1);
    expect(fake.supportCalls, 0);
    expect(arguments, ['documents']);
  });
}
