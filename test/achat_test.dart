import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';

Store _storeAdmin() =>
    Store(const AppUser(id: 'u_admin', nom: 'Patron', role: Role.admin));

Achat _brouillon({String statut = Achat.statutEnAttente}) => Achat(
      id: 'nouveau',
      numero: '',
      boutiqueId: 'bt_siege',
      fournisseurNom: 'ETS Fourni-Tech',
      lignes: const [
        LigneAchat(
            produitId: 'pr_1',
            produitNom: 'Câble RJ45 (305m)',
            quantite: 2,
            prixUnitaire: 18000,
            tauxTVA: 18),
      ],
      date: DateTime.now(),
      statut: statut,
      createdBy: 'u_admin',
      createdAt: DateTime.now(),
    );

void main() {
  group('Achat (modèle)', () {
    test('totaux HT/TVA/TTC et reste dû', () {
      final a = _brouillon();
      expect(a.montantHT, 36000);
      expect(a.montantTVA, closeTo(6480, 0.01));
      expect(a.montantTTC, closeTo(42480, 0.01));
      expect(a.montantRestant, closeTo(42480, 0.01));
      expect(a.estSolde, isFalse);
    });

    test('transitions autorisées', () {
      final a = _brouillon();
      expect(a.peutValider, isTrue);
      expect(a.peutRecevoir, isFalse);
      expect(a.peutPayer, isFalse);
      final valide = a.copyWith(statut: Achat.statutValide);
      expect(valide.peutRecevoir, isTrue);
      expect(valide.peutPayer, isTrue);
      final recu = a.copyWith(statut: Achat.statutRecu);
      expect(recu.peutPayer, isTrue);
      expect(recu.peutAnnuler, isTrue);
    });

    test('JSON aller-retour', () {
      final a = _brouillon().copyWith(montantPaye: 1000);
      final r = Achat.fromJson(a.toJson());
      expect(r.numero, a.numero);
      expect(r.lignes.length, 1);
      expect(r.lignes.first.produitNom, 'Câble RJ45 (305m)');
      expect(r.montantPaye, 1000);
      expect(r.statut, Achat.statutEnAttente);
    });
  });

  group('Store.achats (cycle de vie)', () {
    test('création admin → en_attente avec numéro ACH-', () async {
      final s = _storeAdmin();
      final err = await s.creerAchat(_brouillon());
      expect(err, isNull);
      expect(s.achats.length, 1);
      expect(s.achats.first.statut, Achat.statutEnAttente);
      expect(s.achats.first.numero.startsWith('ACH-'), isTrue);
    });

    test('vendeur → demande imposée', () async {
      final s = Store(const AppUser(
          id: 'u_v', nom: 'Vendeur', role: Role.vendeur));
      final err = await s.creerAchat(_brouillon());
      expect(err, isNull);
      expect(s.achats.first.statut, Achat.statutDemande);
      // Un vendeur ne peut pas valider.
      expect(await s.validerAchat(s.achats.first.id), isNotNull);
    });

    test('validation rejetée sans lignes', () async {
      final s = _storeAdmin();
      final vide = Achat(
        id: 'nouveau', numero: '', boutiqueId: 'bt_siege',
        fournisseurNom: 'X', lignes: const [], date: DateTime.now(),
        createdBy: 'u', createdAt: DateTime.now(),
      );
      expect(await s.creerAchat(vide), isNotNull);
    });

    test('cycle complet : valider → recevoir (stock+) → payer → solder',
        () async {
      final s = _storeAdmin();
      await s.creerAchat(_brouillon());
      final id = s.achats.first.id;
      final stockAvant =
          s.produits.firstWhere((p) => p.id == 'pr_1').stock;

      expect(await s.validerAchat(id), isNull);
      expect(s.achats.first.statut, Achat.statutValide);
      // Validation seule : aucun impact stock.
      expect(s.produits.firstWhere((p) => p.id == 'pr_1').stock,
          stockAvant);

      expect(await s.recevoirAchat(id), isNull);
      expect(s.achats.first.statut, Achat.statutRecu);
      expect(s.produits.firstWhere((p) => p.id == 'pr_1').stock,
          stockAvant + 2);

      final nbChargesAvant = s.depenses.length;
      final reste = s.achats.first.montantRestant;
      expect(await s.payerAchat(id, reste / 2), isNull);
      expect(s.depenses.length, nbChargesAvant + 1);
      expect(s.depenses.first.categorie, 'Fournisseurs');
      expect(s.achats.first.montantRestant, closeTo(reste / 2, 0.01));

      expect(
          await s.payerAchat(id, s.achats.first.montantRestant), isNull);
      expect(s.achats.first.estSolde, isTrue);
      // Surpaiement refusé.
      expect(
          await s.payerAchat(id, s.achats.first.montantRestant), isNotNull);
    });

    test('annulation après réception : contre-écriture stock', () async {
      final s = _storeAdmin();
      await s.creerAchat(_brouillon());
      final id = s.achats.first.id;
      await s.validerAchat(id);
      await s.recevoirAchat(id);
      final stockApresReception =
          s.produits.firstWhere((p) => p.id == 'pr_1').stock;
      expect(
          await s.annulerAchat(id, 'x'), isNotNull); // motif trop court
      expect(await s.annulerAchat(id, 'Erreur de commande'), isNull);
      expect(s.achats.first.statut, Achat.statutAnnule);
      expect(s.achats.first.motifAnnulation, 'Erreur de commande');
      expect(s.produits.firstWhere((p) => p.id == 'pr_1').stock,
          stockApresReception - 2);
    });

    test('indicateurs dashboard', () async {
      final s = _storeAdmin();
      await s.creerAchat(_brouillon());
      expect(s.totalAchatsMois, greaterThan(0));
      expect(s.achatsEnAttente.length, 1);
      await s.validerAchat(s.achats.first.id);
      expect(s.duFournisseurs, greaterThan(0));
    });
  });
}
