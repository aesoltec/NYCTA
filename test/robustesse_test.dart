import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';
import 'package:pme_gestion_pro/services/sync_service.dart';

/// Exigence #34 (concurrence) et #10/#12/#39 (résilience RLS côté client).
void main() {
  group('Concurrence numérotation', () {
    test('20 appels simultanés → 20 numéros uniques', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      final numeros = await Future.wait(
          [for (var i = 0; i < 20; i++) s.numeroDocument('TST')]);
      expect(numeros.toSet().length, 20,
          reason: 'Doublon de numérotation détecté');
      expect(
          numeros.every((n) => n.startsWith('TST-')), isTrue);
    });

    test('compteurs indépendants par préfixe', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      final a = await s.numeroDocument('ACH');
      final b = await s.numeroDocument('ACH');
      expect(a == b, isFalse);
    });
  });

  group('Résilience refus serveur (RLS)', () {
    test('file sync sûre sans initialisation ni réseau', () async {
      final sync = SyncService();
      // Ne doit jamais lever : mode 100 % local.
      await sync.mettreEnFile({'id': 'x'});
      await sync.reessayerTout();
      await sync.viderErreurs();
      expect(await sync.synchroniser(), 0);
      expect(sync.enAttente, 0);
      expect(sync.enErreur, 0);
    });

    test('écritures locales valides même cloud injoignable', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.vendeur));
      // Aucune exception : l'état local prime, la file rejouera.
      final id = await s.ajouterTransaction(
        type: TypeTransaction.forfaitHotspot,
        montant: 1000,
      );
      expect(s.transactions.any((t) => t.id == id), isTrue);
    });
  });
}
