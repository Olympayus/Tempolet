import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runTempolet();

void runTempolet() {
  runApp(const ProviderScope(child: MaterialApp(home: SizedBox.shrink())));
}
