import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fonts déterministes pour les golden tests (PASSES_AUDIT point 20) :
/// Roboto embarqué dans `test/golden/fonts/` (issu du SDK Flutter,
/// licence Apache) chargé via FontLoader — rendu identique en local
/// et en CI, indépendant des fonts système du runner.
Future<void> testExecutable(
    FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chargeur = FontLoader('Roboto')
    ..addFont(_charge('test/golden/fonts/Roboto-Regular.ttf'))
    ..addFont(_charge('test/golden/fonts/Roboto-Medium.ttf'))
    ..addFont(_charge('test/golden/fonts/Roboto-Bold.ttf'));
  await chargeur.load();
  await testMain();
}

Future<ByteData> _charge(String chemin) async {
  final octets = await File(chemin).readAsBytes();
  return ByteData.view(octets.buffer);
}
