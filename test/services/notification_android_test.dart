import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/notification_service.dart';

void main() {
  final sep = Platform.pathSeparator;
  final dossierDrawables = Directory('${Directory.current.path}$sep'
      'android${sep}app${sep}src${sep}main${sep}res${sep}drawable');

  File drawable() => File('${dossierDrawables.path}$sep'
      '${NotificationService.icone}.xml');

  test('le drawable de notification existe REELLEMENT', () {
    expect(drawable().existsSync(), isTrue,
        reason: 'android/app/src/main/res/drawable/'
            '${NotificationService.icone}.xml est absent -> '
            'getIdentifier() renvoie 0, setSmallIcon() leve un NPE et '
            'AUCUNE notification ne s affiche. Erreur vue sur l appareil.');
  });

  test('le nom de l icone est un nom de drawable simple', () {
    // Le plugin resout dans drawable : un nom qualifie (avec @, ou avec
    // un chemin) ne se resout pas.
    const n = NotificationService.icone;
    expect(n.contains('@'), isFalse);
    expect(n.contains('/'), isFalse);
    expect(n.contains('.'), isFalse);
  });

  test('le drawable est un vecteur blanc sur fond transparent', () {
    final xml = drawable().readAsStringSync();
    expect(xml, contains('<vector'),
        reason: 'Android attend un vecteur, pas un PNG');
    // Android impose une silhouette BLANCHE dans la barre d etat.
    expect(xml.toUpperCase(), contains('FFFFFFFF'));
  });

  test('aucune reference obsolete a une icone en mipmap', () {
    // On retire les commentaires : ils citent volontairement le nom
    // obsolete pour expliquer la cause. Ce qui compte est le CODE.
    final code = File('lib/services/notification_service.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('@mipmap/'), isFalse,
        reason: 'reference invalide : le plugin ne resout que dans drawable');
  });

  test('show() est enveloppe : une notification ratee ne casse rien', () {
    // `main.dart` appelle `verifier()` sans await ni try/catch : si
    // `_notifier` laissait remonter une exception, elle deviendrait une
    // erreur asynchrone non traitee au demarrage.
    final dart = File('lib/services/notification_service.dart')
        .readAsStringSync();
    final show = dart.indexOf('_plugin.show');
    expect(show > 0, isTrue);
    expect(dart.lastIndexOf('try {', show) > 0, isTrue,
        reason: '_plugin.show() doit etre enveloppe dans un try');
    expect(dart.indexOf('catch', show) > show, isTrue,
        reason: '_plugin.show() doit avoir un catch');
  });

  test('les deux sources de l icone sont posees', () {
    final dart = File('lib/services/notification_service.dart')
        .readAsStringSync();
    // 1. la source reelle : AndroidNotificationDetails.icon
    expect(dart.contains('icon: icone'), isTrue,
        reason: 'show() resout AndroidNotificationDetails.icon en PREMIER. '
            'Sans lui, setSmallIcon() recoit null -> NPE.');
    // 2. le meta-data manifest (defense en profondeur)
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
        manifest.contains('com.dexterous.flutterlocalnotifications.default_icon'),
        isTrue);
    expect(manifest.contains('@drawable/ic_notification'), isTrue);
    // l'icone du drawable doit etre celle declaree dans le Dart
    expect(manifest.contains('@drawable/${NotificationService.icone}'), isTrue);
  });

}
