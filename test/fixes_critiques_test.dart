import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';

void main() {
  group('Fixes critiques (mission §2.6)', () {
    test('vendeur ne peut pas retirer un article', () async {
      final s = Store(const AppUser(
          id: 'u_v', nom: 'Vendeur', role: Role.vendeur));
      final erreur = await s.supprimerProduit('pr_1', forcerArchive: true);
      expect(erreur, contains('admin'));
      // Le produit est toujours là.
      expect(s.produits.any((p) => p.id == 'pr_1'), isTrue);
    });

    test('admin peut retirer un article sans historique', () async {
      final s = Store(const AppUser(
          id: 'u_a', nom: 'Admin', role: Role.admin));
      final erreur = await s.supprimerProduit('pr_2', forcerArchive: true);
      expect(erreur, isNull);
      expect(s.produits.any((p) => p.id == 'pr_2'), isFalse);
    });

    test('gérant peut retirer, comptable non', () async {
      final g = Store(const AppUser(
          id: 'u_g', nom: 'Gérant', role: Role.gerant));
      expect(await g.supprimerProduit('pr_4', forcerArchive: true),
          isNull);
      final c = Store(const AppUser(
          id: 'u_c', nom: 'Comptable', role: Role.comptable));
      expect(await c.supprimerProduit('pr_3', forcerArchive: true),
          isNotNull);
    });
  });
}
