// Ignore_for_file: unnecessary_import

import '../store.dart';
import '../../models/ecriture.dart';
import '../../services/document_service.dart';

/// Façade StoreComptaDocsFacade : délégation de l'API publique du Store
/// (contenu déplacé à l'identique, API inchangée).
extension StoreComptaDocsFacade on Store {
  // ---------- Comptabilité (délégué à `compta`, Phase 5) ----------
  // Journal immuable : écritures auto-générées, corrections par
  // contre-écriture uniquement (jamais de update/delete).
  List<Ecriture> get ecrituresBoutique => compta.ecrituresBoutique;

  Future<void> pointerEcriture(String id, bool pointee) =>
      compta.pointerEcriture(id, pointee);

  List<Ecriture> get ecrituresARapprocher => compta.ecrituresARapprocher;

  Map<String, double> get balance => compta.balance;

  double get resultatExercice => compta.resultatExercice;

  // ---------- Documents (délégué à `document`, Phase 5) ----------
  Future<String?> enregistrerDocument(DocumentBati d,
          {DateTime? date}) =>
      document.enregistrerDocument(d, date: date);

  /// Modification d'un document BROUILLON (client, lignes, date, taux).
  /// Un document emis se refuse : annuler avec motif puis re-emettre.
  Future<String?> modifierDocument(DocumentBati d,
          {double? tvaPct, String? motif}) =>
      document.modifierDocument(d, tvaPct: tvaPct, motif: motif);

  Future<String?> validerDocument(String numero) =>
      document.validerDocument(numero);

  Future<String?> payerDocument(String numero) =>
      document.payerDocument(numero);

  Future<String?> annulerDocument(String numero, String motif) =>
      document.annulerDocument(numero, motif);

  Future<void> joindreSignatureClient(
          String numero, String cheminLocal) =>
      document.joindreSignatureClient(numero, cheminLocal);

  /// Devis → facture (document repris, numérotation FACT, stock déduit).
  Future<DocumentBati> transformerDevisEnFacture(DocumentBati devis) =>
      document.transformerDevisEnFacture(devis);
}
