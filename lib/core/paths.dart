import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class AppPaths {
  Future<Directory> defaultVaultDirectory();
}

class PlatformAppPaths implements AppPaths {
  const PlatformAppPaths();

  @override
  Future<Directory> defaultVaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return vaultDirectoryIn(docs);
  }
}

Directory vaultDirectoryIn(Directory documents) =>
    Directory(p.join(documents.path, 'Tempolet'));

final appPathsProvider = Provider<AppPaths>((ref) => const PlatformAppPaths());
