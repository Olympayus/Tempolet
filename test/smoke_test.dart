import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/main.dart' as app;

void main() {
  test('entrypoint exists', () => expect(app.runTempolet, isA<Function>()));
}
