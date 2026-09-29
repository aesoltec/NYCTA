import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/persistence/cloud_loader.dart';
import 'package:pme_gestion_pro/models/app_user.dart';
import 'package:pme_gestion_pro/models/enums.dart';
import 'package:pme_gestion_pro/models/transaction.dart';
/// Phase 6 — cloud_loader : traduction lignes Supabase → snapshot,
/// sans backend (données + callbacks injectés).
Map<String, dynamic> _data() => {
      'profile': {
        'nom_entreprise': 'Cloud SARL',
        'devise': 'FCFA',
        'tva': 18,
      },
      'boutiques': [
        {'id': 'b1', 'nom': 'Siège', 'adresse': '', 'siege': true},
      ],
      'produits': [
        {
          'id': 'p1',
          'boutique_id': 'b1',
          'libelle': 'Câble',
          'categorie': 'Test',
          'prix_achat': 1000,
          'prix_vente': 1500,
          'quantite_stock': 4,
          'seuil_alerte': 3,
          'date_ajout': '2026-09-20T00:00:00.000',
          'images': []
        }
      ],
      'partenaires': [],
      'transactions': [
        {
          'id': 'tx1',
          'boutique_id': 'b1',
          'employe_id': 'uuid-1',
          'type': 'prestation_service',
          'montant': 10000,
          'cout': 2000,
          'statut': 'paye',
          'details': {},
          'date_transaction': '2026-09-26T10:00:00.000'
        }
      ],
      'charges': [],
      'budgets': [
        {'categorie': 'Loyer', 'montant': 150000}
      ],
      'fonds': [
        {'boutique_id': 'b1', 'montant': 500000}
      ],
      'mon_profil': {
        'id': 'uuid-1',
        'nom': 'Admin',
        'role': 'admin',
      },
      'mes_boutiques': [
        {'boutique_id': 'b1'}
      ],
      'users': [],
      'categories': [
        {'type': 'produit', 'nom': 'Test'},
      ],
      'clients': [],
      'fournisseurs': [],
      'messages': [],
      'evenements': [],
      'notes': [],
      'feedbacks': [],
      'catalogue': [],
      'achats': [],
      'mouvements': [],
      'ecritures': [],
      'documents': [],
    };

void main() {
  group('CloudLoader.traduire', () {
    test('profil + produits + budgets + catégories', () async {
      final s = await CloudLoader.traduire(_data(),
          sessionUser:
              const AppUser(id: 'x', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: false,
          genererId: () => 'g');
      expect(s.profile.nomEntreprise, 'Cloud SARL');
      expect(s.profile.tva, 18);
      expect(s.produits.length, 1);
      expect(s.produits.first.stock, 4);
      expect(s.produits.first.dateAjout, DateTime(2026, 9, 20));
      expect(s.profile.budgetsMensuels, {'Loyer': 150000.0});
      expect(s.profile.fondsRoulement, {'b1': 500000.0});
      expect(s.catsProduit, ['Test']);
    });

    test('session résolue via mon_profil', () async {
      final s = await CloudLoader.traduire(_data(),
          sessionUser:
              const AppUser(id: 'x', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: true,
          genererId: () => 'g');
      expect(s.user.id, 'uuid-1');
      expect(s.user.role, Role.admin);
      expect(s.profilCloudManquant, isFalse);
      expect(s.boutiqueId, 'b1');
      expect(s.transactions.first.employeId, 'uuid-1');
    });

    test('sans mon_profil + uid → stagiaire + flag', () async {
      final d = _data()..remove('mon_profil');
      final s = await CloudLoader.traduire(d,
          sessionUser:
              const AppUser(id: 'x', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: false,
          genererId: () => 'g',
          uidReelForTest: 'uuid-reel');
      expect(s.user.id, 'uuid-reel');
      expect(s.user.role, Role.stagiaire);
      expect(s.profilCloudManquant, isTrue);
    });

    test('documents reconstruits via callbacks', () async {
      final d = _data();
      d['documents'] = [
        {
          'id': 'd1',
          'type': 'facture',
          'numero': 'FACT-2026-00001',
          'date_doc': '2026-09-26T00:00:00.000',
          'client_nom': 'Cli',
          'total_ht': 10000,
          'tva': 1800,
          'total_ttc': 11800,
          'statut': 'emis',
          'signature_client_path': 'sig.png'
        }
      ];
      final s = await CloudLoader.traduire(d,
          sessionUser:
              const AppUser(id: 'x', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: false,
          genererId: () => 'g',
          chargerLignesDocs: (_) async => {
                'd1': [
                  {
                    'libelle': 'Presta',
                    'quantite': 1,
                    'prix_unitaire': 10000
                  }
                ]
              },
          signatureLocale: (_) async => '/tmp/sig.png');
      expect(s.documentsEmis.length, 1);
      expect(s.documentsEmis.first.numero, 'FACT-2026-00001');
      expect(s.documentsEmis.first.lignes.length, 1);
      expect(s.documentsEmis.first.signatureClientPath,
          '/tmp/sig.png');
    });

    test('type transaction snake_case converti', () async {
      final s = await CloudLoader.traduire(_data(),
          sessionUser:
              const AppUser(id: 'x', nom: 'S', role: Role.admin),
          sessionPartenaireId: null,
          sessionProfilManquant: false,
          genererId: () => 'g');
      expect(s.transactions.first.type,
          TypeTransaction.prestationService);
    });
  });
}
