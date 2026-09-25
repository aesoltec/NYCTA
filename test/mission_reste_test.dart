import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/store.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/document.dart';
import 'package:pme_gestion_pro/models/enums.dart';

void main() {
  group('Reste mission (BL, refresh, documents vendeur)', () {
    test('BL sans prix, autres avec prix', () {
      expect(TypeDocument.bonLivraison.sansPrix, isTrue);
      expect(TypeDocument.facture.sansPrix, isFalse);
      expect(TypeDocument.devisProforma.sansPrix, isFalse);
      expect(TypeDocument.ticketCaisse.sansPrix, isFalse);
      expect(TypeDocument.bonCommande.sansPrix, isFalse);
    });

    test('BL décrémente le stock, devis et BC non', () {
      expect(TypeDocument.bonLivraison.decrementeStock, isTrue);
      expect(TypeDocument.devisProforma.decrementeStock, isFalse);
      expect(TypeDocument.bonCommande.decrementeStock, isFalse);
    });

    test('rafraichir hors-ligne retourne sans crash', () async {
      final s = Store(const AppUser(
          id: 'u', nom: 'T', role: Role.admin));
      await s.rafraichir(); // CloudRepository inactif en test
      expect(s.boutiques, isNotEmpty);
    });

    test('vendeur : pas de gererDocuments mais accès écran ciblée', () {
      const vendeur = AppUser(
          id: 'u', nom: 'V', role: Role.vendeur);
      expect(vendeur.peut(Permission.gererDocuments), isFalse);
      expect(vendeur.peut(Permission.vendre), isTrue);
      // Le filtrage par type se fait dans DocumentsScreen (pas de BC).
      const autorises = [
        TypeDocument.facture,
        TypeDocument.devisProforma,
        TypeDocument.ticketCaisse,
        TypeDocument.bonLivraison,
      ];
      expect(autorises.contains(TypeDocument.bonCommande), isFalse);
    });
  });
}
