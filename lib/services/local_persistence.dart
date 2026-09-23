import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// Persistance locale de l'état complet du Store (mode démo hors-ligne).
/// Sauvegarde JSON déclenchée automatiquement à chaque mutation (debounce
/// 600 ms pour éviter les écritures en rafale).
class LocalPersistence {
  static const _boxName = 'store_v1';
  static const _cleEtat = 'etat';
  static Box? _box;
  static bool _initialise = false;

  static Future<void> init() async {
    if (_initialise) return;
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _initialise = true;
  }

  static Map<dynamic, dynamic>? load() => _box?.get(_cleEtat) as Map?;

  static void save(Map<String, dynamic> json) {
    _box?.put(_cleEtat, json);
  }
}
