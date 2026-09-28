import 'package:flutter/foundation.dart';
import '../../models/client.dart';
import '../../services/cloud_repository.dart';

/// Clients (Phase 2 — découpage Store) : fichier par boutique.
/// Rôle : CRUD + filtre boutique + anti-doublon nom/boutique.
/// Dépendances : `genererId` injecté ; `boutiqueId` mutable (synchronisé
/// par la façade en Phase 5).
/// Extrait à l'identique de `Store` (l.911-945, clientsBoutique).
class ClientNotifier extends ChangeNotifier {
  final String Function() genererId;
  String boutiqueId;

  final List<Client> clients = [];

  ClientNotifier({required this.genererId, this.boutiqueId = ''});

  List<Client> get clientsBoutique =>
      clients.where((c) => c.boutiqueId == boutiqueId).toList();

  Future<String?> ajouterClient(Client c) async {
    if (c.nom.trim().length < 2) return 'Nom trop court';
    if (clients.any((x) =>
        x.boutiqueId == c.boutiqueId &&
        x.nom.toLowerCase() == c.nom.trim().toLowerCase())) {
      return 'Ce client existe déjà dans cette boutique';
    }
    final client = Client(
      id: genererId(),
      boutiqueId: c.boutiqueId,
      nom: c.nom,
      telephone: c.telephone,
      email: c.email,
      adresse: c.adresse,
      rccm: c.rccm,
      ifu: c.ifu,
      rib: c.rib,
      logoPath: c.logoPath,
    );
    clients.add(client);
    notifyListeners();
    await CloudRepository.upsertClient(client);
    return null;
  }

  Future<void> majClient(Client c) async {
    final i = clients.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      clients[i] = c;
      notifyListeners();
      await CloudRepository.upsertClient(c);
    }
  }
}
