import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/achat_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/mouvement_stock.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';

/// Phase 3 — AchatNotifier : cycle complet (callbacks injectés).
int _seq = 500;

({AchatNotifier n, List<String> appels}) _notifier(
    {Role role = Role.admin}) {
  final appels = <String>[];
  final n = AchatNotifier(
    session: SessionNotifier(
        AppUser(id: 'u1', nom: 'T', role: role)),
    genererId: () => 'a${_seq++}',
    numeroDocument: (p) async => '$p-2026-00001',
    achats: [],
    produits: [
      const Produit(
          id: 'p1',
          boutiqueId: 'b1',
          libelle: 'Câble',
          categorie: 'A',
          prixAchat: 1000,
          prixVente: 1500,
          stock: 10),
    ],
    catalogue: [],
    depenses: [],
    mouvements: [],
    fileUpsert: (t, p) async {
      appels.add('file:$t');
    },
    journaliser: (
        {required String produitId,
        required String produitNom,
        required String type,
        required int quantite,
        required int stockApres,
        required String boutiqueId,
        String motif = '',
        String refId = '',
        DateTime? date}) async {
      appels.add('mvt:$type:$quantite');
    },
    ajouterChargeDepense: (c) async {
      appels.add('charge:${c.montant}');
    },
    comptabiliserReception: (a) async {
      appels.add('compta-rec:${a.id}');
    },
    comptabiliserPaiement: (a, m, mode) async {
      appels.add('compta-pay:$m:$mode');
    },
    contrePasser: (ref, motif) async {
      appels.add('contre:$motif');
    },
  );
  return (n: n, appels: appels);
}

Achat _brouillon() => Achat(
    id: '',
    numero: '',
    boutiqueId: 'b1',
    fournisseurNom: 'ETS Fourni',
    lignes: const [
      LigneAchat(
          produitId: 'p1',
          produitNom: 'Câble',
          quantite: 2,
          prixUnitaire: 1200),
    ],
    date: DateTime(2026, 9, 1),
    createdBy: 'u1',
    createdAt: DateTime(2026, 9, 1));

void main() {
  group('AchatNotifier création/validation', () {
    test('creer : validations + statut demande vendeur', () async {
      final (:n, :appels) = _notifier(role: Role.vendeur);
      expect(
          await n.creerAchat(_brouillon()
              .copyWith(fournisseurNom: 'X')),
          contains('Fournisseur requis'));
      final vide = _brouillon().copyWith(lignes: const []);
      expect(await n.creerAchat(vide), contains('ligne'));
      final mauvaiseQte = _brouillon().copyWith(lignes: const [
        LigneAchat(produitNom: 'Câble', quantite: 0, prixUnitaire: 1)
      ]);
      expect(await n.creerAchat(mauvaiseQte), contains('Quantité'));
      final mauvaisPrix = _brouillon().copyWith(lignes: const [
        LigneAchat(
            produitNom: 'Câble', quantite: 1, prixUnitaire: -1)
      ]);
      expect(await n.creerAchat(mauvaisPrix), contains('Prix'));
      expect(await n.creerAchat(_brouillon()), isNull);
      expect(n.achats.first.statut, Achat.statutDemande);
      expect(n.achats.first.numero, 'ACH-2026-00001');
    });

    test('admin : en_attente sauf demande explicite', () async {
      final (:n, :appels) = _notifier();
      expect(await n.creerAchat(_brouillon()), isNull);
      expect(n.achats.first.statut, Achat.statutEnAttente);
    });

    test('majAchat : brouillon seul + lignes requises', () async {
      final (:n, :appels) = _notifier();
      expect(await n.majAchat(_brouillon()), 'Achat introuvable');
      await n.creerAchat(_brouillon());
      final id = n.achats.first.id;
      expect(
          await n.majAchat(
              n.achats.first.copyWith(lignes: const [])),
          contains('ligne'));
      expect(
          await n.majAchat(
              n.achats.first.copyWith(notes: 'OK')),
          isNull);
      await n.validerAchat(id);
      expect(
          await n.majAchat(n.achats.first.copyWith(notes: 'X')),
          contains('modifiable'));
    });

    test('validerAchat : permission + transition', () async {
      final (n: vendeur, appels: appelsVendeur) =
          _notifier(role: Role.vendeur);
      await vendeur.creerAchat(_brouillon());
      expect(
          await vendeur.validerAchat(vendeur.achats.first.id),
          contains('Réservé'));
      final (:n, :appels) = _notifier();
      expect(await n.validerAchat('zz'), 'Achat introuvable');
      await n.creerAchat(_brouillon());
      expect(await n.validerAchat(n.achats.first.id), isNull);
      expect(n.achats.first.statut, Achat.statutValide);
      expect(await n.validerAchat(n.achats.first.id),
          contains('incompatible'));
    });
  });

  group('AchatNotifier réception/paiement/annulation', () {
    test('recevoir : CUMP + mouvement + compta', () async {
      final (:n, :appels) = _notifier();
      await n.creerAchat(_brouillon());
      expect(await n.recevoirAchat('zz'), 'Achat introuvable');
      final id = n.achats.first.id;
      expect(await n.recevoirAchat(id),
          contains('Validez')); // pas encore valide
      await n.validerAchat(id);
      expect(await n.recevoirAchat(id), isNull);
      expect(n.achats.first.statut, Achat.statutRecu);
      // CUMP : (10×1000 + 2×1200) / 12 = 1033.33.
      expect(n.produits.first.stock, 12);
      expect(n.produits.first.prixAchat, closeTo(1033.33, 0.01));
      expect(appels, contains('mvt:entree:2'));
      expect(appels, contains('compta-rec:$id'));
    });

    test('recevoir : crée le produit si ligne libre', () async {
      final (:n, :appels) = _notifier();
      final libre = _brouillon().copyWith(lignes: const [
        LigneAchat(
            produitNom: 'Article libre', quantite: 3, prixUnitaire: 500)
      ]);
      await n.creerAchat(libre);
      final id = n.achats.first.id;
      await n.validerAchat(id);
      await n.recevoirAchat(id);
      final cree = n.produits
          .where((p) => p.libelle == 'Article libre')
          .toList();
      expect(cree.length, 1);
      expect(cree.first.stock, 3);
      expect(cree.first.prixVente, 500.0);
    });

    test('payer : partiel puis solde, surpaiement refusé', () async {
      final (n: vendeur, appels: appelsVendeur) =
          _notifier(role: Role.vendeur);
      await vendeur.creerAchat(_brouillon());
      expect(await vendeur.payerAchat(vendeur.achats.first.id, 100),
          contains('Réservé'));
      // La création a persisté (file), mais le paiement refusé n'a
      // rien ajouté : ni charge, ni écriture.
      expect(appelsVendeur, ['file:achats']);
      final (n: a, appels: appels) = _notifier();
      await a.creerAchat(_brouillon());
      final id = a.achats.first.id;
      await a.validerAchat(id);
      await a.recevoirAchat(id);
      final total = a.achats.first.montantTTC; // 2×1200 = 2400
      expect(await a.payerAchat(id, 0), contains('Montant > 0'));
      expect(await a.payerAchat(id, total + 1),
          contains('reste dû'));
      expect(await a.payerAchat(id, 1000, mode: 'virement'),
          isNull);
      expect(a.achats.first.montantPaye, 1000.0);
      expect(a.depenses.length, 1);
      expect(a.depenses.first.categorie, 'Fournisseurs');
      expect(appels,
          contains('compta-pay:1000.0:virement'));
      expect(await a.payerAchat(id, total - 1000), isNull);
      expect(a.achats.first.estSolde, isTrue);
      expect(await a.payerAchat(id, 1), contains('Aucun montant'));
    });

    test('annuler : motif + contre-écriture stock + compta', () async {
      final (:n, :appels) = _notifier();
      await n.creerAchat(_brouillon());
      final id = n.achats.first.id;
      expect(await n.annulerAchat(id, 'x'), contains('Motif'));
      await n.validerAchat(id);
      await n.recevoirAchat(id); // stock 10 → 12
      expect(
          await n.annulerAchat(id, 'Erreur de commande'), isNull);
      expect(n.achats.first.statut, Achat.statutAnnule);
      expect(n.produits.first.stock, 10); // 12 − 2
      expect(appels, contains('contre:annulation ACH-2026-00001'));
      expect(await n.annulerAchat(id, 'Encore'),
          contains('déjà annulé'));
    });

    test('getters boutique : en-attente, total mois, dû', () async {
      final (:n, :appels) = _notifier();
      n.boutiqueId = 'b1';
      await n.creerAchat(_brouillon());
      expect(n.achatsBoutique.length, 1);
      expect(n.achatsEnAttente.length, 1);
      expect(n.totalAchatsMois('2026-09'), 2400.0);
      expect(n.totalAchatsMois('2026-08'), 0.0);
      expect(n.duFournisseurs, 0.0); // en_attente : pas de dette
      await n.validerAchat(n.achats.first.id);
      expect(n.duFournisseurs, 2400.0);
      n.boutiqueId = 'b2';
      expect(n.achatsBoutique, isEmpty);
      expect(n.duFournisseurs, 0.0);
    });
  });
}
