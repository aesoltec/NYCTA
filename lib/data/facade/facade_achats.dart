// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/achat.dart';
import '../../models/partage.dart';
import '../../models/partenaire.dart';
import '../services/partage_service.dart';

/// Façade StoreAchatsFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreAchatsFacade on Store {
  // ---------- Partenaires (délégué à `partenaire`, Phase 5) ----------
  Future<String?> ajouterPartenaire(Partenaire p) =>
      partenaire.ajouterPartenaire(p);

  Future<String?> majPartenaire(Partenaire p) =>
      partenaire.majPartenaire(p);

  Future<void> desactiverPartenaire(String id) =>
      partenaire.desactiverPartenaire(id);

  Future<String?> supprimerPartenaire(String id) =>
      partenaire.supprimerPartenaire(id);

  // ---------- Partenaires : clôture (délégué, Phase 5) ----------
  double ventesPartenaireMois(String partenaireId, String mois) =>
      PartageService.totalVentes(
          transactions, partenaireId, mois);

  bool partageExiste(String partenaireId, String mois) =>
      partenaire.partageExiste(partenaireId, mois);

  Future<Partage> cloturerMois(String partenaireId, String mois) =>
      partenaire.cloturerMois(partenaireId, mois, boutiqueId);

  List<Partage> partagesDe(String partenaireId) =>
      partenaire.partagesDe(partenaireId);

  // ---------- Achats (délégué à `achat`, Phase 5) ----------
  List<Achat> get achatsBoutique => achat.achatsBoutique;

  List<Achat> get achatsEnAttente => achat.achatsEnAttente;

  double get totalAchatsMois => achat.totalAchatsMois(moisCourant);

  double get duFournisseurs => achat.duFournisseurs;

  Future<String?> creerAchat(Achat brouillon) =>
      achat.creerAchat(brouillon);

  Future<String?> majAchat(Achat maj) => achat.majAchat(maj);

  Future<String?> validerAchat(String id) => achat.validerAchat(id);

  Future<String?> recevoirAchat(String id) => achat.recevoirAchat(id);

  Future<String?> payerAchat(String id, double montant,
          {String? mode}) =>
      achat.payerAchat(id, montant, mode: mode);

  Future<String?> annulerAchat(String id, String motif) =>
      achat.annulerAchat(id, motif);

}
