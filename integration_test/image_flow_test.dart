import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:pme_gestion_pro/data/gallery/gallery_service.dart';
import 'package:pme_gestion_pro/data/persistence/cloud_loader.dart';
import 'package:pme_gestion_pro/data/persistence/serializer.dart';
import 'package:pme_gestion_pro/data/models/media_item.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/company_profile.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';
import 'package:pme_gestion_pro/screens/gallery/gallery_screen.dart';
import 'package:pme_gestion_pro/screens/stock/stock_screen.dart';

/// Parcours « association d'images » — exécutable sur l'appareil
/// (`flutter test integration_test/image_flow_test.dart -d <id>`).
///
/// Ces scénarios ne sont PAS couverts par les tests widget : ils valident
/// le comportement de bout en bout du modèle + du service de galerie, qui
/// est précisément là où étaient les deux bugs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> _ecran(WidgetTester tester, Widget enfant, Store store) async {
    addTearDown(() => store.dispose());
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(home: enfant),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Store _store() =>
      Store(const AppUser(id: 'u', nom: 'Test', role: Role.admin));

  group('Association images — modèle', () {
    testWidgets('retirer la dernière image ne la fait pas revenir',
        (tester) async {
      final p = Produit(
        id: 'p1',
        boutiqueId: 'b1',
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
        images: const ['/docs/media/produit/a.jpg'],
      );
      expect(p.imagePath, '/docs/media/produit/a.jpg');

      // Le scénario exact du bug : on retire tout.
      final r = p.copyWith(images: const <String>[]);
      expect(r.images, isEmpty);
      expect(r.imagePath, isNull,
          reason: 'l ancienne image ne doit pas survivre au vidage');
    });

    testWidgets('remplacer les images change le principal', (tester) async {
      final p = Produit(
        id: 'p1',
        boutiqueId: 'b1',
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
        images: const ['/docs/media/produit/ancienne.jpg'],
      );
      final r = p.copyWith(images: const ['/docs/media/produit/nouvelle.jpg']);
      expect(r.imagePath, '/docs/media/produit/nouvelle.jpg');
    });
  });

  group('Association images — galerie', () {
    testWidgets('affecter depuis la galerie stocke un chemin affichable',
        (tester) async {
      final store = _store();
      await _ecran(tester, const SizedBox(), store);

      final item = MediaItem(
        cle: 'produit_x_1700000000_aa11bb.jpg',
        cheminLocal: File.fromUri(Directory.systemTemp.uri).existsSync()
            ? null
            : null,
      );
      final reel = item.copyWith(
          cheminLocal: '${Directory.systemTemp.path}/produit_x_1700000000_aa11bb.jpg');

      final produit = Produit(
        id: 'p1',
        boutiqueId: store.boutiqueId,
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
      );
      store.produits.add(produit);

      final r = GalleryService.affecterProduit(produit, reel,
          produits: store.produits);
      expect(r, isNotNull);

      // BUG 2 : ce qui est stocké doit être un chemin local (donc
      // affichable) ou une URL — jamais un nom de fichier nu.
      final stocke = r!.images.first;
      expect(stocke, reel.apercu);
      expect(stocke == reel.cle,
          isFalse,
          reason: 'un nom de fichier seul ne s affiche pas et ne se '
              'téléverse pas');
      expect(stocke.contains('/') || stocke.startsWith('http'), isTrue);
      expect(r.imagePath, stocke, reason: 'la nouvelle image est la principale');
    });

    testWidgets('la même image ne peut pas être ajoutée deux fois',
        (tester) async {
      final store = _store();
      await _ecran(tester, const SizedBox(), store);
      final produit = Produit(
        id: 'p1',
        boutiqueId: store.boutiqueId,
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
      );
      store.produits.add(produit);

      const item = MediaItem(
          cle: 'x.jpg', cheminLocal: '/docs/media/galerie/x.jpg');
      final r1 = GalleryService.affecterProduit(produit, item,
          produits: store.produits);
      expect(r1, isNotNull);
      final r2 = GalleryService.affecterProduit(r1!, item,
          produits: store.produits);
      expect(r2, isNull, reason: 'doublon refusé');
    });

    testWidgets('retirer une image de la galerie ne laisse pas de trace',
        (tester) async {
      final store = _store();
      await _ecran(tester, const SizedBox(), store);
      const item = MediaItem(
          cle: 'x.jpg', cheminLocal: '/docs/media/galerie/x.jpg');
      final produit = Produit(
        id: 'p1',
        boutiqueId: store.boutiqueId,
        libelle: 'Cable',
        categorie: 'Test',
        prixAchat: 100,
        prixVente: 200,
        stock: 5,
      );
      store.produits.add(produit);
      final avec = GalleryService.affecterProduit(produit, item,
          produits: store.produits)!;
      final sans = GalleryService.retirerProduit(avec, item,
          produits: store.produits);
      expect(sans!.images, isEmpty);
      expect(sans.imagePath, isNull);
    });
  });

  group('Désérialisation — image_path héréditaire', () {
    // Les instantanes / lignes Supabase écrits avant la 1.13.4 portent
    // `image_path` nul ALORS QUE la galerie contient la photo : sans repli
    // la photo restait invisible au rechargement. Verifie sur l'appareil.
    testWidgets('snapshot local : image_path nul + galerie pleine',
        (tester) async {
      final json = StoreSerializer.toJson(StoreSnapshot(
        profile: const CompanyProfile(nomEntreprise: 'T', devise: 'FCFA', tva: 18),
        user: const AppUser(id: 'u', nom: 'T', role: Role.admin),
        boutiqueId: 'b1',
        produits: [
          Produit(
            id: 'p1',
            boutiqueId: 'b1',
            libelle: 'Cable',
            categorie: 'Test',
            prixAchat: 100,
            prixVente: 200,
            stock: 5,
          ),
        ],
      ));
      final p = Map<String, dynamic>.from((json['produits'] as List).first as Map);
      p['image_path'] = null;
      p['images'] = ['/docs/media/produit/p1_1_ab.jpg'];
      json['produits'] = [p];

      final relu = StoreSerializer.fromJson(json, genererId: () => 'g');
      final produit = relu.produits.first;
      expect(produit.images, ['/docs/media/produit/p1_1_ab.jpg']);
      expect(produit.imagePath, '/docs/media/produit/p1_1_ab.jpg',
          reason: 'la photo est dans la galerie, elle doit redevenir visible');
    });

    testWidgets('cloud : image_path nul + galerie pleine', (tester) async {
      final data = <String, dynamic>{
        'profile': {'nom_entreprise': 'T', 'devise': 'FCFA', 'tva': 18},
        'boutiques': [
          {'id': 'b1', 'nom': 'Siege', 'adresse': '', 'siege': true},
        ],
        'produits': [
          {
            'id': 'p1',
            'boutique_id': 'b1',
            'libelle': 'Cable',
            'categorie': 'Test',
            'prix_achat': 100,
            'prix_vente': 200,
            'quantite_stock': 5,
            'seuil_alerte': 3,
            'image_path': null,
            'images': ['/docs/media/produit/p1_1_ab.jpg'],
          }
        ],
        'partenaires': <dynamic>[],
        'transactions': <dynamic>[],
        'charges': <dynamic>[],
        'budgets': <dynamic>[],
        'fonds': <dynamic>[],
        'mon_profil': {'id': 'u', 'nom': 'Admin', 'role': 'admin'},
        'mes_boutiques': [
          {'boutique_id': 'b1'}
        ],
        'users': <dynamic>[],
        'categories': <dynamic>[],
        'catalogue': <dynamic>[],
        'depenses': <dynamic>[],
        'echeances': <dynamic>[],
        'documents': <dynamic>[],
      };

      final s = await tester.runAsync(() => CloudLoader.traduire(data,
          sessionUser:
              const AppUser(id: 'u', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: false,
          genererId: () => 'g'));

      final produit = s!.produits.first;
      expect(produit.imagePath, '/docs/media/produit/p1_1_ab.jpg');
    });

    testWidgets('ni image_path ni galerie → aucune photo', (tester) async {
      final json = StoreSerializer.toJson(StoreSnapshot(
        profile: const CompanyProfile(nomEntreprise: 'T', devise: 'FCFA', tva: 18),
        user: const AppUser(id: 'u', nom: 'T', role: Role.admin),
        boutiqueId: 'b1',
        produits: [
          Produit(
            id: 'p1',
            boutiqueId: 'b1',
            libelle: 'Cable',
            categorie: 'Test',
            prixAchat: 100,
            prixVente: 200,
            stock: 5,
          ),
        ],
      ));
      final p = Map<String, dynamic>.from((json['produits'] as List).first as Map);
      p['image_path'] = null;
      p['images'] = <String>[];
      json['produits'] = [p];

      final relu = StoreSerializer.fromJson(json, genererId: () => 'g');
      expect(relu.produits.first.imagePath, isNull);
      expect(relu.produits.first.images, isEmpty);
    });
  });

  group('Écrans — aucune exception sur l appareil', () {
    testWidgets('écran Stock s affiche', (tester) async {
      final store = _store();
      await _ecran(tester, const StockScreen(), store);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('écran Galerie s affiche', (tester) async {
      final store = _store();
      await _ecran(tester, const GalleryScreen(), store);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(tester.takeException(), isNull);
    });
  });
}
