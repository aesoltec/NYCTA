// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/analytique.dart';
import '../../models/charge.dart';
import '../../models/enums.dart';
import '../../models/transaction.dart';
import '../services/analytique_service.dart';
import '../services/caisse_service.dart';

/// Façade StoreVentesFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreVentesFacade on Store {
  Future<String> ajouterTransaction({
    required TypeTransaction type,
    required double montant,
    double cout = 0,
    String? clientNom,
    String? partenaireId,
    Map<String, dynamic> details = const {},
    DateTime? date,
    StatutPaiement statut = StatutPaiement.paye,
  }) =>
      transaction.ajouterTransaction(
        type: type,
        montant: montant,
        cout: cout,
        clientNom: clientNom,
        partenaireId: partenaireId,
        details: details,
        date: date,
        statut: statut,
      );

  Future<String?> majTransaction(Tx maj) =>
      transaction.majTransaction(maj);

  Future<void> supprimerTransaction(String id) =>
      transaction.supprimerTransaction(id);

  /// Encaissement d'une vente à crédit (délégué à `transaction`).
  Future<String?> encaisserVente(String id) =>
      transaction.encaisserVente(id);

  /// Créances clients : ventes non soldées (délégué à `transaction`).
  List<Tx> get creances => transaction.creances;

  double get totalCreances => transaction.totalCreances;

  /// Balance âgée : encours impayé par tranche (délégué, Phase 5).
  Map<String, double> get balanceAgee =>
      AnalytiqueService.balanceAgee(creances, DateTime.now());

  /// TVA par mois (délégué à `AnalytiqueService`, Phase 5).
  Map<int, (double, double)> tvaParMois(int annee) =>
      AnalytiqueService.tvaParMois(ecrituresBoutique, annee);

  // ---------- Tableau de bord ----------
  List<Tx> get txBoutique => transaction.txBoutique;

  List<Tx> get txJour => AnalytiqueService.duJour(
      transactions, boutiqueId, DateTime.now());

  double get caJour =>
      AnalytiqueService.caJour(transactions, boutiqueId, DateTime.now());

  double get margeJour => AnalytiqueService.margeJour(
      transactions, boutiqueId, DateTime.now());


  List<Tx> get txMois =>
      AnalytiqueService.duMois(transactions, boutiqueId, moisCourant);

  double get caMois =>
      AnalytiqueService.caMois(transactions, boutiqueId, moisCourant);

  double get margeMois =>
      AnalytiqueService.margeMois(transactions, boutiqueId, moisCourant);

  Map<TypeTransaction, double> get caParType =>
      AnalytiqueService.caParType(txMois);

  Map<String, double> get caParJour => AnalytiqueService.caParJour(
      transaction.txBoutique, DateTime.now());

  Map<String, double> get fraisMoMoMois =>
      AnalytiqueService.fraisMoMo(txMois);


  // ---------- Charges (délégué à `charge`, Phase 5) ----------
  Future<void> ajouterCharge(Charge c) => charge.ajouterCharge(c);

  List<Charge> get depensesBoutique => charge.depensesBoutique;

  Future<String?> majCharge(Charge maj) => charge.majCharge(maj);

  Future<void> supprimerCharge(String id) =>
      charge.supprimerCharge(id);

  List<Charge> get depensesMois =>
      charge.depensesMois(moisCourant);

  double get totalDepensesMois =>
      charge.totalDepensesMois(moisCourant);

  double depensesCategorieMois(String categorie) =>
      charge.depensesCategorieMois(categorie, moisCourant);

  Map<String, (double, double)> get suiviBudgets =>
      charge.suiviBudgets(moisCourant);

  Future<void> genererChargesRecurrentesSiNouveauMois() =>
      charge.genererChargesRecurrentesSiNouveauMois(moisCourant);

  // ---------- Trésorerie (délégué à `profil` + `CaisseService`) ----------
  double get fondsRoulementCourant =>
      profil.profile.fondsRoulement[boutiqueId] ?? 0;

  Future<void> definirFondsRoulement(
          String boutiqueId, double montant) =>
      profil.definirFonds(boutiqueId, montant);

  double soldeCaisse(String boutiqueId) => CaisseService.solde(
      transactions: transactions,
      depenses: depenses,
      boutiqueId: boutiqueId,
      fondsRoulement:
          profil.profile.fondsRoulement[boutiqueId] ?? 0);

  double get soldeCaisseCourant => soldeCaisse(boutiqueId);

  // ---------- Analytique (délégué à `analytique`, Phase 5) ----------
  List<AgregatPeriode> ca7Jours({DateTime? fin}) =>
      analytique.ca7Jours(fin: fin);

  List<AgregatPeriode> depenses7Jours({DateTime? fin}) =>
      analytique.depenses7Jours(fin: fin);

  List<AgregatPeriode> caParMois(int annee) =>
      analytique.caParMois(annee);

  List<AgregatPeriode> depensesParMois(int annee) =>
      analytique.depensesParMois(annee);

  List<AgregatPeriode> caParAnnee() => analytique.caParAnnee();

  List<AgregatPeriode> depensesParAnnee() =>
      analytique.depensesParAnnee();

  List<int> anneesDonnees() => analytique.anneesDonnees();

}
