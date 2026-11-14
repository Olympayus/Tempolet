import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tempolet/core/paths.dart';

void main() {
  test('vaultDirectoryIn appends Tempolet', () {
    final docs = Directory(p.join('C:', 'Users', 'me', 'Documents'));
    expect(vaultDirectoryIn(docs).path, p.join(docs.path, 'Tempolet'));
  });
}
