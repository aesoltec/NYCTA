import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

Store _store() =>
    Store(const AppUser(id: 'u', nom: 'T', role: Role.admin));

void main() {
  group('Rapprochement bancaire', () {
    test('pointer/depointer sans toucher aux montants', () async {
      final s = _store();
      await s.ajouterTransaction(
          type: TypeTransaction.mobileMoney, montant: 10000);
      final bq =
          s.ecritures.where((e) => e.journal == 'BQ').toList();
      expect(bq, isNotEmpty);
      final id = bq.first.id;
      final soldeAvant = s.balance;
      await s.pointerEcriture(id, true);
      expect(
          s.ecritures.firstWhere((e) => e.id == id).pointee, isTrue);
      expect(s.ecrituresARapprocher.any((e) => e.id == id), isFalse);
      // Montants intacts.
      expect(s.balance, soldeAvant);
      await s.pointerEcriture(id, false);
      expect(
          s.ecritures.firstWhere((e) => e.id == id).pointee, isFalse);
    });

    test('ecrituresARapprocher ne liste que BQ/CA non pointées', () async {
      final s = _store();
      await s.ajouterTransaction(
          type: TypeTransaction.prestationService, montant: 5000);
      await s.ajouterCharge(Charge(
        id: 'c', boutiqueId: s.boutiqueId, categorie: 'Loyer',
        libelle: 'Loyer', montant: 1000, date: DateTime.now(),
      ));
      // VT + OD : rien à rapprocher (pas de journal BQ/CA).
      expect(s.ecrituresARapprocher, isEmpty);
    });
  });
}
