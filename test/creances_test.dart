import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

Store _store() =>
    Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

void main() {
  group('Crédit client, relances, balance âgée, TVA', () {
    test('vente impayée → créance, puis encaissement', () async {
      final s = _store();
      await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 20000,
        clientNom: 'Client Crédit',
        statut: StatutPaiement.impaye,
      );
      expect(s.creances.length, 1);
      expect(s.totalCreances, 20000);
      final id = s.creances.first.id;
      expect(await s.encaisserVente(id), isNull);
      expect(s.creances, isEmpty);
      // Encaissement déjà soldé refusé.
      expect(await s.encaisserVente(id), isNotNull);
    });

    test('balance âgée : tranches cohérentes', () async {
      final s = _store();
      await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 5000,
        clientNom: 'A',
        statut: StatutPaiement.impaye,
        date: DateTime.now().subtract(const Duration(days: 45)),
      );
      await s.ajouterTransaction(
        type: TypeTransaction.prestationService,
        montant: 3000,
        clientNom: 'B',
        statut: StatutPaiement.impaye,
        date: DateTime.now().subtract(const Duration(days: 100)),
      );
      final b = s.balanceAgee;
      expect(b['31-60 j'], 5000);
      expect(b['+90 j'], 3000);
      expect(b['0-30 j'], 0);
      expect(
          b.values.fold(0.0, (t, v) => t + v), s.totalCreances);
    });

    test('TVA par mois : collectée − déductible', () async {
      final s = _store();
      // TVA démo = 0 : aucune écriture 443/445 générée.
      final an = DateTime.now().year;
      final serie = s.tvaParMois(an);
      expect(serie.length, 12);
      expect(
          serie.values.fold(0.0, (t, e) => t + e.$1), 0);
      // Charge mappée : pas de TVA sur les charges (HT direct).
      await s.ajouterCharge(Charge(
        id: 'c', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer', montant: 1000, date: DateTime.now(),
      ));
      expect(s.tvaParMois(an).values.fold(0.0, (t, e) => t + e.$2),
          0);
    });
  });
}
