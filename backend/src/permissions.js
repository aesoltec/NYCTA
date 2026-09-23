// Matrice rôle → permissions — DOIT rester identique à
// lib/models/enums.dart côté Flutter (source de vérité documentée).
const P = {
  vendre: 'vendre', gererStock: 'gererStock', voirCaisse: 'voirCaisse',
  voirRapports: 'voirRapports', gererPartenaires: 'gererPartenaires',
  cloturerMois: 'cloturerMois', gererDepenses: 'gererDepenses',
  configurer: 'configurer', gererUtilisateurs: 'gererUtilisateurs',
  gererDocuments: 'gererDocuments',
};

const rolePermissions = {
  admin: Object.values(P),
  gerant: [P.vendre, P.gererStock, P.voirCaisse, P.voirRapports,
           P.gererPartenaires, P.cloturerMois, P.gererDepenses,
           P.configurer, P.gererDocuments],
  comptable: [P.voirCaisse, P.voirRapports, P.gererDepenses, P.gererDocuments, P.vendre],
  caissier: [P.vendre, P.voirCaisse, P.gererDocuments],
  vendeur: [P.vendre, P.gererStock],
  stagiaire: [],
  partenaire: [P.vendre],
};

module.exports = { P, rolePermissions };
