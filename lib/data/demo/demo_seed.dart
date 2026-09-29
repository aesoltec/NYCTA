import '../../models/app_user.dart';
import '../../models/boutique.dart';
import '../../models/charge.dart';
import '../../models/company_profile.dart';
import '../../models/enums.dart';
import '../../models/partenaire.dart';
import '../../models/produit.dart';
import '../../models/transaction.dart';

/// Données de démonstration (Phase 6) : contenu déplacé à l'identique
/// de `Store._seedDemo`. Listes injectées (partagées avec le Store),
/// aucun état propre — appel une seule fois au boot démo.
class DemoSeed {
  const DemoSeed._();

  static void appliquer({
    required List<Boutique> boutiques,
    required List<AppUser> users,
    required void Function(CompanyProfile p) setProfile,
    required List<Partenaire> partenaires,
    required List<Produit> produits,
    required List<Charge> depenses,
    required List<Tx> transactions,
    required String Function() genererId,
    required String employeId,
  }) {
    boutiques.addAll([
      const Boutique(id: 'bt_siege', nom: 'Siège — Hotspot & Services', adresse: 'Centre-ville', siege: true),
      const Boutique(id: 'bt_marche', nom: 'Boutique Marché', adresse: 'Grand marché'),
    ]);
    users.add(const AppUser(id: 'u_admin', nom: 'Patron', role: Role.admin));
    setProfile(const CompanyProfile(
      nomEntreprise: 'SARL TECH-SERVICES & CO',
      devise: 'FCFA',
      telephone: '+225 07 07 07 07 07',
      email: 'contact@techservices.ci',
      adresse: 'Abidjan, Cocody — Rue des Jardins',
      rccm: 'CI-ABJ-2023-B-12345',
      ifu: 'IFU-123456789A',
      messagePied: 'Merci de votre confiance — Paiement sous 8 jours.',
      fondsRoulement: {'bt_siege': 500000, 'bt_marche': 300000},
      budgetsMensuels: {'Loyer': 150000, 'Salaires': 400000, 'Électricité & Eau': 60000},
    ));
    partenaires.addAll([
      const Partenaire(id: 'pt_1', nom: 'Kouassi Jean', telephone: '07 08 09 10 11', localisation: 'Quieré', taux: 0.60),
      const Partenaire(id: 'pt_2', nom: 'Traoré Awa', telephone: '05 06 07 08 09', localisation: 'Gare routière', taux: 0.55),
    ]);
    produits.addAll([
      Produit(id: 'pr_1', boutiqueId: 'bt_siege', libelle: 'Câble RJ45 (305m)', categorie: 'Télécom & Réseau', prixAchat: 18000, prixVente: 25000, stock: 4, seuil: 3, dateAjout: DateTime.now().subtract(const Duration(days: 2))),
      Produit(id: 'pr_2', boutiqueId: 'bt_siege', libelle: 'Disjoncteur 32A', categorie: 'Électricité', prixAchat: 2500, prixVente: 4000, stock: 25, seuil: 5, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_3', boutiqueId: 'bt_siege', libelle: 'Écran 24 pouces', categorie: 'Accessoire PC', prixAchat: 45000, prixVente: 60000, stock: 2, seuil: 2, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_4', boutiqueId: 'bt_siege', libelle: 'Chargeur type-C 25W', categorie: 'Accessoire téléphone', prixAchat: 3000, prixVente: 5500, stock: 40, seuil: 8, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
      Produit(id: 'pr_5', boutiqueId: 'bt_marche', libelle: 'Caméra IP Hikvision', categorie: 'Télécom & Réseau', prixAchat: 22000, prixVente: 32000, stock: 6, seuil: 2, dateAjout: DateTime.now().subtract(const Duration(days: 60))),
    ]);
    depenses.addAll([
      Charge(id: genererId(), boutiqueId: 'bt_siege', categorie: 'Loyer', libelle: 'Loyer local siège', montant: 150000, date: DateTime.now().subtract(const Duration(days: 8))),
      Charge(id: genererId(), boutiqueId: 'bt_siege', categorie: 'Électricité & Eau', libelle: 'Facture CIE', montant: 45000, date: DateTime.now().subtract(const Duration(days: 4))),
      Charge(id: genererId(), boutiqueId: 'bt_siege', categorie: 'Fournisseurs', libelle: 'Achat câbles et connectiques', montant: 75000, date: DateTime.now().subtract(const Duration(days: 2))),
    ]);

    final now = DateTime.now();
    Tx make(TypeTransaction type, double m, double c, String bt,
            {String? client, String? pt, Map<String, dynamic> d = const {}, int jour = 0, int heure = 10}) =>
        Tx(
          id: genererId(), boutiqueId: bt, employeId: employeId, type: type,
          montant: m, cout: c, clientNom: client, partenaireId: pt,
          details: d, date: now.subtract(Duration(days: jour, hours: now.hour - heure)),
        );

    transactions.addAll([
      make(TypeTransaction.prestationService, 25000, 3000, 'bt_siege', client: 'M. Koné', d: {'domaine': 'Vidéosurveillance', 'description': 'Installation 4 caméras'}, jour: 0, heure: 9),
      make(TypeTransaction.mobileMoney, 50000, 0, 'bt_siege', d: {'operateur': 'Orange Money', 'frais': 400, 'operation': 'Dépôt'}, jour: 0, heure: 10),
      make(TypeTransaction.mobileMoney, 30000, 0, 'bt_siege', d: {'operateur': 'Moov Money', 'frais': 250, 'operation': 'Retrait'}, jour: 0, heure: 11),
      make(TypeTransaction.creditCommunication, 2000, 1960, 'bt_siege', d: {'operateur': 'Orange'}, jour: 0, heure: 12),
      make(TypeTransaction.forfaitHotspot, 1000, 0, 'bt_siege', d: {'duree': '1 heure'}, jour: 0, heure: 13),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 jour'}, jour: 0, heure: 14),
      make(TypeTransaction.prestationService, 15000, 2000, 'bt_siege', client: 'Mme Bamba', d: {'domaine': 'Informatique', 'description': 'Formatage + installation'}, jour: 1),
      make(TypeTransaction.forfaitHotspot, 5000, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 semaine'}, jour: 1),
      make(TypeTransaction.forfaitHotspot, 10000, 0, 'bt_siege', pt: 'pt_2', d: {'duree': '1 mois'}, jour: 1),
      make(TypeTransaction.creditCommunication, 5000, 4900, 'bt_siege', d: {'operateur': 'Moov'}, jour: 1),
      make(TypeTransaction.venteMateriel, 64000, 44000, 'bt_marche', client: 'Entreprise Sahel', d: {'lignes': [{'libelle': 'Caméra IP Hikvision', 'quantite': 2}]}, jour: 3),
      make(TypeTransaction.prestationService, 40000, 5000, 'bt_marche', client: 'Pharmacie du Nord', d: {'domaine': 'Électricité', 'description': 'Mise aux normes tableau'}, jour: 5),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_2', d: {'duree': '1 jour'}, jour: 2),
      make(TypeTransaction.mobileMoney, 100000, 0, 'bt_siege', d: {'operateur': 'Telecel Money', 'frais': 800, 'operation': 'Transfert'}, jour: 2),
      make(TypeTransaction.forfaitHotspot, 2500, 0, 'bt_siege', pt: 'pt_1', d: {'duree': '1 jour'}, jour: 4),
      make(TypeTransaction.forfaitHotspot, 1000, 0, 'bt_siege', d: {'duree': '1 heure'}, jour: 4),
    ]);
  }
}
