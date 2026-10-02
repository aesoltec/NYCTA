import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/persistence/serializer.dart';
import 'package:pme_gestion_pro/models/achat.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/company_profile.dart';
import 'package:pme_gestion_pro/models/ecriture.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/mouvement_stock.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/models/tarif.dart';
import 'package:pme_gestion_pro/models/transaction.dart';

/// Phase 6 — serializer : roundtrip JSON local sans perte.
StoreSnapshot _snapshot() => StoreSnapshot(
      profile: const CompanyProfile(
          nomEntreprise: 'Test SARL', devise: 'FCFA', tva: 18),
      user: const AppUser(id: 'u1', nom: 'T', role: Role.admin),
      boutiqueId: 'b1',
      produits: [
        Produit(
            id: 'p1',
            boutiqueId: 'b1',
            libelle: 'Câble',
            categorie: 'Test',
            prixAchat: 1000,
            prixVente: 1500,
            stock: 4,
            seuil: 3,
            images: const ['img1'],
            dateAjout: DateTime(2026, 9, 20)),
      ],
      catalogue: [
        Tarif(
            id: 't1',
            libelle: 'Forfait',
            prix: 5000,
            dateAjout: DateTime(2026, 9, 25)),
      ],
      transactions: [
        Tx(
            id: 'tx1',
            boutiqueId: 'b1',
            employeId: 'u1',
            type: TypeTransaction.prestationService,
            montant: 10000,
            cout: 2000,
            date: DateTime(2026, 9, 26)),
      ],
      depenses: [
        Charge(
            id: 'c1',
            boutiqueId: 'b1',
            categorie: 'Loyer',
            libelle: 'Loyer',
            montant: 50000,
            date: DateTime(2026, 9, 1)),
      ],
      catsProduit: const ['Test'],
      achats: [
        Achat(
            id: 'a1',
            numero: 'ACH-2026-00001',
            boutiqueId: 'b1',
            fournisseurNom: 'F',
            lignes: const [
              LigneAchat(
                  produitNom: 'X', quantite: 1, prixUnitaire: 100)
            ],
            date: DateTime(2026, 9, 5),
            createdBy: 'u1',
            createdAt: DateTime(2026, 9, 5)),
      ],
      mouvements: [
        MouvementStock(
            id: 'm1',
            boutiqueId: 'b1',
            produitId: 'p1',
            produitNom: 'Câble',
            type: MouvementStock.entree,
            quantite: 4,
            stockApres: 4,
            date: DateTime(2026, 9, 20),
            createdBy: 'u1'),
      ],
      ecritures: [
        Ecriture(
            id: 'e1',
            journal: 'OD',
            date: DateTime(2026, 9, 1),
            compte: '622',
            libelle: 'Loyer',
            debit: 50000,
            credit: 0,
            refId: 'c1',
            boutiqueId: 'b1',
            createdBy: 'u1'),
      ],
    );

void main() {
  group('StoreSerializer roundtrip', () {
    test('toJson clés + fromJson sans perte', () {
      final json = StoreSerializer.toJson(_snapshot());
      expect(json['version'], 1);
      expect(json['boutique_id_courante'], 'b1');
      final s2 = StoreSerializer.fromJson(json,
          genererId: () => 'g1');
      expect(s2.profile.nomEntreprise, 'Test SARL');
      expect(s2.profile.tva, 18);
      expect(s2.user.id, 'u1');
      expect(s2.boutiqueId, 'b1');
      expect(s2.produits.length, 1);
      expect(s2.produits.first.libelle, 'Câble');
      expect(s2.produits.first.stock, 4);
      expect(s2.produits.first.images, ['img1']);
      expect(s2.produits.first.dateAjout, DateTime(2026, 9, 20));
      expect(s2.catalogue.first.nouveau, isNotNull);
      expect(s2.transactions.first.employeId, 'u1');
      expect(s2.transactions.first.montant, 10000.0);
      expect(s2.depenses.first.montant, 50000.0);
      expect(s2.catsProduit, ['Test']);
      expect(s2.achats.first.numero, 'ACH-2026-00001');
      expect(s2.mouvements.first.type, MouvementStock.entree);
      expect(s2.ecritures.first.compte, '622');
    });

    test('double roundtrip stable', () {
      final s1 = StoreSerializer.fromJson(
          StoreSerializer.toJson(_snapshot()),
          genererId: () => 'g1');
      final s2 = StoreSerializer.fromJson(
          StoreSerializer.toJson(s1),
          genererId: () => 'g1');
      expect(s2.produits.first.libelle,
          s1.produits.first.libelle);
      expect(s2.transactions.first.montant,
          s1.transactions.first.montant);
      expect(s2.profile.budgetsMensuels,
          s1.profile.budgetsMensuels);
    });

    test('map vide → défauts (jamais d\'exception)', () {
      final s = StoreSerializer.fromJson({},
          utilisateurSecours: const AppUser(
              id: 'ux', nom: 'S', role: Role.vendeur));
      expect(s.profile.nomEntreprise, 'Mon Entreprise');
      expect(s.user.id, 'ux');
      expect(s.produits, isEmpty);
      expect(s.catsProduit, isEmpty);
    });

    test('partages recalculés (ids injectés)', () {
      final s = StoreSerializer.fromJson({
        'partages': [
          {
            'partenaire_id': 'pt1',
            'mois': '2026-09',
            'total_ventes': 10000,
            'taux': 0.6
          }
        ]
      }, genererId: () => 'pid');
      expect(s.partages.length, 1);
      expect(s.partages.first.id, 'pid');
      expect(s.partages.first.partPartenaire, 6000.0);
    });

    test('utilisateur secours quand absent', () {
      final s = StoreSerializer.fromJson({
        'produits': [],
      },
          utilisateurSecours: const AppUser(
              id: 'sess', nom: 'S', role: Role.gerant));
      expect(s.user.id, 'sess');
    });
  });

  group('image_path hereditaire (fiches ecrites avant la 1.13.4)', () {
    Map<String, dynamic> _jsonLegacy(String? imagePath, List<String> imgs) {
      final json = StoreSerializer.toJson(_snapshot());
      final p = (json['produits'] as List).first as Map<String, dynamic>;
      p['image_path'] = imagePath;
      p['images'] = imgs;
      return json;
    }

    test('image_path nul + galerie pleine : la photo redevient principale',
        () {
      final json = _jsonLegacy(null, ['/docs/media/produit/p1_1_ab.jpg']);
      final s2 = StoreSerializer.fromJson(json, genererId: () => 'g1');
      final p = s2.produits.first;
      expect(p.images, ['/docs/media/produit/p1_1_ab.jpg']);
      expect(p.imagePath, '/docs/media/produit/p1_1_ab.jpg',
          reason: 'la photo est dans la galerie, elle doit etre visible');
    });

    test('image_path fourni reste prioritaire', () {
      final json = _jsonLegacy('/forcer.jpg', ['/a.jpg', '/b.jpg']);
      final s2 = StoreSerializer.fromJson(json, genererId: () => 'g1');
      expect(s2.produits.first.imagePath, '/forcer.jpg');
    });

    test('ni image_path ni galerie : aucune photo', () {
      final json = _jsonLegacy(null, const []);
      final s2 = StoreSerializer.fromJson(json, genererId: () => 'g1');
      expect(s2.produits.first.imagePath, isNull);
      expect(s2.produits.first.images, isEmpty);
    });
  });

}
