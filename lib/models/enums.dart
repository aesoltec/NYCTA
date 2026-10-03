/// Rôles de l'entreprise — 7 rôles avec matrice de permissions.
/// Anticipation senior : chaque action de l'app est protégée par une
/// Permission ; le rôle de l'utilisateur connecté la débloque ou non.
enum Role { admin, gerant, comptable, caissier, vendeur, stagiaire, partenaire }

enum Permission {
  vendre,            // encaisser (toutes activités de vente)

  // ---- Stock : quatre actes distincts, quatre droits distincts.
  // Un seul `gererStock` conflait création de fiche, modification et
  // retrait : un vendeur pouvait donc créer un article, ce qui n'a rien
  // de terrain (le prix d'achat fixe la marge). Chaque droit ci-dessous
  // correspond a une LIGNE de MATRICE_PERMISSIONS.md.
  voirStock,         // LIRE le catalogue et les quantités
  creerProduit,      // CRÉER une fiche catalogue (prix d'achat → marge)
  modifierProduit,   // MODIFIER une fiche (prix de vente, photo, seuil, quantité)
  retirerProduit,    // RETIRER / ARCHIVER un article du stock

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
    Permission.vendre,
    Permission.voirStock, Permission.creerProduit, Permission.modifierProduit,
    Permission.retirerProduit,
    Permission.voirCaisse,
    Permission.voirRapports, Permission.gererPartenaires, Permission.cloturerMois,
    Permission.gererDepenses, Permission.configurer, Permission.gererUtilisateurs,
    Permission.gererDocuments, Permission.gererAchats,
  },
  // Le gérant gère le catalogue comme l'admin, SAUF les comptes
  // utilisateurs (ligne « Gérer utilisateurs » : admin seul).
  Role.gerant: {
    Permission.vendre,
    Permission.voirStock, Permission.creerProduit, Permission.modifierProduit,
    Permission.retirerProduit,
    Permission.voirCaisse,
    Permission.voirRapports, Permission.gererPartenaires, Permission.cloturerMois,
    Permission.gererDepenses, Permission.configurer, Permission.gererDocuments,
    Permission.gererAchats,
  },
  // Le comptable suit le stock (écarts, valorisation) sans le modifier :
  // créer un produit relèverait de la direction, et le modifier fausserait
  // l'inventaire du compta.
  Role.comptable: {
    Permission.voirStock,
    Permission.voirCaisse, Permission.voirRapports, Permission.gererDepenses,
    Permission.gererDocuments, Permission.vendre, Permission.gererAchats,
  },
  // Le caissier encaisse et voit l'état des articles pour ne pas vendre du
  // inexistant : lecture seule sur le stock.
  Role.caissier: {
    Permission.vendre, Permission.voirStock, Permission.voirCaisse,
    Permission.gererDocuments,
  },
  // Option A : le vendeur LIT le stock (ne pas vendre de l'inexistant),
  // MODIFIE ses fiches (autonomie terrain : prix de vente, photo, seuil,
  // quantité constatée) mais ne CREE pas de fiche et ne retire rien.
  Role.vendeur: {
    Permission.vendre, Permission.voirStock, Permission.modifierProduit,
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
