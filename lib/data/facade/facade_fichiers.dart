// Ignore_for_file: unnecessary_import

import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/fournisseur.dart';
import '../store.dart';

/// Façade des fichiers tiers (clients, fournisseurs) : délégation de
/// l'API publique du Store (contenu déplacé à l'identique, API inchangée).
extension StoreFichiersFacade on Store {
  // ---------- Clients (délégué à `client`, Phase 5) ----------
  List<Client> get clientsBoutique => client.clientsBoutique;

  Future<String?> ajouterClient(Client c) =>
      client.ajouterClient(c);

  Future<void> majClient(Client c) => client.majClient(c);

  /// Noms des clients avec impayé en cours (filtre « Avec crédit »).
  /// Façade : aucun Notifier ne porte ce calcul transverse.
  Set<String> get clientsAvecCredit => {
        for (final t in transactions)
          if (t.statut != StatutPaiement.paye &&
              (t.clientNom ?? '').trim().isNotEmpty)
            t.clientNom!.trim(),
      };

  // ---------- Fournisseurs (délégué à `fournisseur`, Phase 5) ----------
  Future<String?> ajouterFournisseur(Fournisseur f) =>
      fournisseur.ajouterFournisseur(f);

  Future<void> majFournisseur(Fournisseur f) =>
      fournisseur.majFournisseur(f);

  Future<void> supprimerFournisseur(String id) =>
      fournisseur.supprimerFournisseur(id);
}
