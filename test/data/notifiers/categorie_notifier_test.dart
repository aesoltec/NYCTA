import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/normalisation.dart';
import 'package:pme_gestion_pro/data/notifiers/categorie_notifier.dart';
import 'package:pme_gestion_pro/models/charge.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Phase 1 — CategorieNotifier (listes injectées, anti-doublon accents).
CategorieNotifier _notifier() => CategorieNotifier(
    produits: [
      Produit(
          id: 'p1', boutiqueId: 'b1', libelle: 'Câble',
          categorie: 'Électricité', prixAchat: 100, prixVente: 150),
    ],
    depenses: [
      Charge(
          id: 'c1',
          boutiqueId: 'b1',
          categorie: 'Loyer',
          libelle: 'Loyer',
          montant: 50000,
          date: DateTime(2026, 9, 1)),
    ]);

void main() {
  group('Normalisation', () {
    test('sansAccents', () {
      expect(Normalisation.sansAccents('Électricité'), 'Electricite');
      expect(Normalisation.sansAccents('Ça coûte'), 'Ca coute');
    });

    test('memeCategorie casse + accents', () {
      expect(Normalisation.memeCategorie('Électricité', 'electricite'),
          isTrue);
      expect(Normalisation.memeCategorie('Loyer', 'LOYER'), isTrue);
      expect(Normalisation.memeCategorie('Loyer', 'Salaires'), isFalse);
    });
  });

  group('CategorieNotifier catégories', () {
    test('ajouterCategorie : trop court + doublon accentué', () async {
      final n = _notifier();
      expect(await n.ajouterCategorie('X', produit: true),
          isNotNull);
      expect(
          await n.ajouterCategorie('electricite', produit: true),
          contains('Électricité'));
      expect(
          await n.ajouterCategorie('Plomberie', produit: true),
          isNull);
      expect(n.catsProduit.contains('Plomberie'), isTrue);
    });

    test('renommerCategorie : cascade produits', () async {
      final n = _notifier();
      final err = await n.renommerCategorie(
          'Électricité', 'Élec', produit: true);
      expect(err, isNull);
      expect(n.catsProduit.contains('Élec'), isTrue);
      expect(n.produits.first.categorie, 'Élec');
    });

    test('renommerCategorie : introuvable + doublon', () async {
      final n = _notifier();
      expect(await n.renommerCategorie('ZZZ', 'YY', produit: true),
          'Catégorie introuvable');
      await n.ajouterCategorie('Plomberie', produit: true);
      expect(
          await n.renommerCategorie('Plomberie', 'électricité',
              produit: true),
          'Cette catégorie existe déjà');
    });

    test('supprimerCategorie : garde-fou utilisation', () async {
      final n = _notifier();
      expect(
          await n.supprimerCategorie('Électricité', produit: true),
          contains('renommez-la'));
      await n.ajouterCategorie('Inutile', produit: true);
      expect(await n.supprimerCategorie('Inutile', produit: true),
          isNull);
      expect(n.catsProduit.contains('Inutile'), isFalse);
    });

    test('supprimerCategorie charge utilisée', () async {
      final n = _notifier();
      expect(await n.supprimerCategorie('Loyer', produit: false),
          contains('renommez-la'));
    });
  });

  group('CategorieNotifier listes dynamiques', () {
    test('ajouterValeurListe : vide + doublon', () async {
      final n = _notifier();
      expect(await n.ajouterValeurListe('operateur_momo', '  '),
          'Valeur requise');
      expect(
          await n.ajouterValeurListe(
              'operateur_momo', 'orange money'),
          'Cette valeur existe déjà');
      expect(await n.ajouterValeurListe('operateur_momo', 'WaveX'),
          isNull);
      expect(n.opsMobileMoney.contains('WaveX'), isTrue);
    });

    test('renommerValeurListe + type inconnu', () async {
      final n = _notifier();
      expect(
          () => n.ajouterValeurListe('zzz', 'X'), throwsArgumentError);
      expect(
          await n.renommerValeurListe(
              'domaine_prestation', 'ZZZ', 'YY'),
          'Valeur introuvable');
    });

    test('supprimerValeurListe', () async {
      final n = _notifier();
      await n.ajouterValeurListe('duree_forfait', '3 jours');
      expect(
          await n.supprimerValeurListe('duree_forfait', '3 jours'),
          isNull);
      expect(n.dureesForfaitListe.contains('3 jours'), isFalse);
    });
  });
}
