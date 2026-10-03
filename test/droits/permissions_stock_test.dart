import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/produit_notifier.dart';
import 'package:pme_gestion_pro/data/notifiers/session_notifier.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/produit.dart';

/// Verrouille l'OPTION A : le vendeur LIT le stock, MODIFIE ses fiches,
/// ne CREE pas d'article et ne retire rien.
///
/// Ces tests portent sur les GARDES MÉTIER, pas sur l'affichage : une
/// regle d'acces qui vit uniquement dans un `if (visible)` n'est pas une
/// regle d'acces.
int _seq = 900;

ProduitNotifier _notifier(Role role) => ProduitNotifier(
      session: SessionNotifier(AppUser(id: 'u1', nom: 'T', role: role)),
      genererId: () => 'p${_seq++}',
      produits: [
        Produit(
            id: 'p1',
            boutiqueId: 'b1',
            libelle: 'Cable',
            categorie: 'A',
            prixAchat: 1000,
            prixVente: 1500,
            stock: 10)
      ],
      catalogue: [],
      transactions: [],
      mouvements: [],
      journaliserMouvement:
          ({required produitId,
          required produitNom,
          required type,
          required quantite,
          required stockApres,
          required boutiqueId,
          String motif = '',
          String refId = '',
          DateTime? date}) async {},
      boutiqueId: 'b1',
    );

Produit _nouveau() => Produit(
    id: 'nouveau',
    boutiqueId: 'b1',
    libelle: 'Article Direction',
    categorie: 'A',
    prixAchat: 100,
    prixVente: 150,
    stock: 1);

void main() {
  group('matrice des droits stock (option A)', () {
    test('le vendeur LIT le stock', () {
      expect(rolePermissions[Role.vendeur], contains(Permission.voirStock),
          reason: 'il doit consulter le stock pour ne pas vendre du vide');
    });

    test('le vendeur MODIFIE ses fiches', () {
      expect(rolePermissions[Role.vendeur],
          contains(Permission.modifierProduit));
    });

    test('le vendeur ne CREE pas de fiche et ne retire rien', () {
      expect(rolePermissions[Role.vendeur],
          isNot(contains(Permission.creerProduit)));
      expect(rolePermissions[Role.vendeur],
          isNot(contains(Permission.retirerProduit)));
    });

    test('caissier et comptable lisent sans modifier', () {
      for (final r in [Role.caissier, Role.comptable]) {
        expect(rolePermissions[r], contains(Permission.voirStock));
        expect(rolePermissions[r], isNot(contains(Permission.creerProduit)));
        expect(rolePermissions[r], isNot(contains(Permission.modifierProduit)));
        expect(rolePermissions[r], isNot(contains(Permission.retirerProduit)));
      }
    });

    test('admin et gerant possedent les quatre', () {
      for (final r in [Role.admin, Role.gerant]) {
        for (final p in [
          Permission.voirStock,
          Permission.creerProduit,
          Permission.modifierProduit,
          Permission.retirerProduit,
        ]) {
          expect(rolePermissions[r], contains(p), reason: '$r / $p');
        }
      }
    });

    test('le stagiaire n a AUCUN droit de stock', () {
      expect(rolePermissions[Role.stagiaire], isEmpty);
    });

    test('gerer utilisateurs reste reserve a l admin', () {
      expect(rolePermissions[Role.gerant],
          isNot(contains(Permission.gererUtilisateurs)));
    });
  });

  group('garde metier : la regle ne vit plus dans l UI', () {
    test('un vendeur ne peut PAS creer de produit', () async {
      final n = _notifier(Role.vendeur);
      final err = await n.ajouterProduit(_nouveau());
      expect(err, isNotNull,
          reason: 'creer une fiche fixe le prix d achat, donc la marge : '
              'acte de direction');
      expect(n.produits.any((p) => p.libelle == 'Article Direction'), isFalse,
          reason: 'rien ne doit avoir ete ajoute');
    });

    test('un caissier ne peut PAS creer de produit', () async {
      expect(await _notifier(Role.caissier).ajouterProduit(_nouveau()), isNotNull);
    });

    test('un vendeur PEUT modifier une fiche', () async {
      final n = _notifier(Role.vendeur);
      final err =
          await n.majProduit(n.produits.first.copyWith(prixVente: 1800));
      expect(err, isNull, reason: 'autonomie terrain : prix de vente');
    });

    test('un caissier ne peut PAS modifier une fiche', () async {
      final n = _notifier(Role.caissier);
      expect(
          await n.majProduit(n.produits.first.copyWith(prixVente: 1800)),
          isNotNull);
    });

    test('un vendeur ne peut PAS retirer un article', () async {
      final n = _notifier(Role.vendeur);
      final avant = n.produits.length;
      await n.archiverProduit('p1');
      expect(n.produits.length, avant,
          reason: 'archivage refuse : le produit reste en place');
      final err = await n.supprimerProduit('p1');
      expect(err, isNotNull);
      expect(err, contains('admin'),
          reason: 'le refus doit nommer les roles autorises');
    });

    test('un gerant peut retirer un article', () async {
      final n = _notifier(Role.gerant);
      final avant = n.produits.length;
      await n.archiverProduit('p1');
      expect(n.produits.length, avant - 1);
    });

    test('un admin peut creer un produit', () async {
      expect(await _notifier(Role.admin).ajouterProduit(_nouveau()), isNull);
    });
  });
}
