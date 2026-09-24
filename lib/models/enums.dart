/// Rôles de l'entreprise — 7 rôles avec matrice de permissions.
/// Anticipation senior : chaque action de l'app est protégée par une
/// Permission ; le rôle de l'utilisateur connecté la débloque ou non.
enum Role { admin, gerant, comptable, caissier, vendeur, stagiaire, partenaire }

enum Permission {
  vendre,            // encaisser (toutes activités de vente)
  gererStock,        // ajouter/modifier produits, entrées de stock
  voirCaisse,        // voir trésorerie & soldes
  voirRapports,      // rapports & statistiques
  gererPartenaires,  // CRUD partenaires hotspot
  cloturerMois,      // clôture & partage mensuel
  gererDepenses,     // saisir les charges/dépenses
  configurer,        // configuration entreprise (identité, fiscal, budgets…)
  gererUtilisateurs, // créer comptes, affecter rôles et boutiques
  gererDocuments,    // émettre factures, devis, bons, tickets
  gererAchats,       // achats fournisseurs (Phase 2)
}

/// Matrice rôle → permissions. L'administrateur a tout, par définition.
const Map<Role, Set<Permission>> rolePermissions = {
  Role.admin: {
    Permission.vendre, Permission.gererStock, Permission.voirCaisse,
    Permission.voirRapports, Permission.gererPartenaires, Permission.cloturerMois,
    Permission.gererDepenses, Permission.configurer, Permission.gererUtilisateurs,
    Permission.gererDocuments, Permission.gererAchats,
  },
  Role.gerant: {
    Permission.vendre, Permission.gererStock, Permission.voirCaisse,
    Permission.voirRapports, Permission.gererPartenaires, Permission.cloturerMois,
    Permission.gererDepenses, Permission.configurer, Permission.gererDocuments,
    Permission.gererAchats,
  },
  Role.comptable: {
    Permission.voirCaisse, Permission.voirRapports, Permission.gererDepenses,
    Permission.gererDocuments, Permission.vendre, Permission.gererAchats,
  },
  Role.caissier: {
    Permission.vendre, Permission.voirCaisse, Permission.gererDocuments,
  },
  Role.vendeur: {
    Permission.vendre, Permission.gererStock,
  },
  Role.stagiaire: {
    // Lecture seule : aucune permission d'écriture.
  },
  Role.partenaire: {
    // Phase P8 : saisie de ses propres ventes de forfaits hotspot.
    Permission.vendre,
  },
};

extension RoleX on Role {
  String get label => switch (this) {
        Role.admin => 'Administrateur',
        Role.gerant => 'Gérant',
        Role.comptable => 'Comptable',
        Role.caissier => 'Caissier(ère)',
        Role.vendeur => 'Vendeur',
        Role.stagiaire => 'Stagiaire',
        Role.partenaire => 'Partenaire hotspot',
      };
}

enum StatutPaiement { paye, partiel, impaye }
enum StatutPartage { enCours, valide, paye }
