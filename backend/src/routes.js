const express = require('express');
// Rate-limit sur la connexion : 10 tentatives / 5 min par IP (anti brute-force)
let loginLimiter = null;
try {
  const rateLimit = require('express-rate-limit');
  loginLimiter = rateLimit({
    windowMs: 5 * 60 * 1000, max: 10,
    standardHeaders: true, legacyHeaders: false,
    message: { erreur: 'Trop de tentatives — réessayez dans 5 minutes.' },
  });
} catch (_) {/* package optionnel */}
const { authentifie, exiger, login } = require('./auth');
const { crud } = require('./crud');
const { q } = require('./db');
const { P } = require('./permissions');

const router = express.Router();

// ---------- Auth (public) ----------
router.post('/auth/login', loginLimiter || ((req, res, next) => next()), login);

// ---------- Tout le reste : JWT obligatoire ----------
router.use(authentifie);

// ---------- Ressources CRUD ----------
// { table, idColonne, champs en liste blanche, permissions lecture/écriture }
const ressources = {
  '/transactions': {
    table: 'transactions', idColonne: 'id',
    champs: ['id', 'boutique_id', 'employe_id', 'type', 'montant', 'cout',
             'statut', 'client_id', 'client_nom', 'partenaire_id',
             'details', 'date_transaction'],
    lecture: [P.voirCaisse, P.voirRapports, P.vendre], ecriture: [P.vendre],
  },
  '/produits': {
    table: 'produits', idColonne: 'id',
    champs: ['id', 'boutique_id', 'libelle', 'categorie', 'prix_achat',
             'prix_vente', 'quantite_stock', 'seuil_alerte', 'image_path', 'actif'],
    lecture: [P.vendre, P.gererStock], ecriture: [P.gererStock],
  },
  '/charges': {
    table: 'charges', idColonne: 'id',
    champs: ['id', 'boutique_id', 'categorie', 'libelle', 'montant',
             'date_charge', 'recurrente', 'created_by'],
    lecture: [P.gererDepenses, P.voirCaisse], ecriture: [P.gererDepenses],
  },
  '/partenaires': {
    table: 'partenaires', idColonne: 'id',
    champs: ['id', 'nom', 'telephone', 'localisation', 'taux_partage', 'user_id', 'actif'],
    lecture: [P.gererPartenaires, P.cloturerMois], ecriture: [P.gererPartenaires],
  },
  '/clients': {
    table: 'clients', idColonne: 'id',
    champs: ['id', 'boutique_id', 'nom', 'telephone', 'adresse'],
    lecture: [P.vendre], ecriture: [P.vendre],
  },
  '/boutiques': {
    table: 'boutiques', idColonne: 'id',
    champs: ['id', 'nom', 'adresse', 'telephone', 'siege', 'actif'],
    lecture: [P.vendre], ecriture: [P.gererUtilisateurs, P.configurer],
  },
};

for (const [route, cfg] of Object.entries(ressources)) {
  const c = crud(cfg);
  router.get(route, exiger(...cfg.lecture), c.liste);
  router.get(`${route}/:id`, exiger(...cfg.lecture), c.detail);
  router.post(route, exiger(...cfg.ecriture), c.creer);
  router.put(`${route}/:id`, exiger(...cfg.ecriture), c.maj);
}

// ---------- Profil entreprise (Configuration) ----------
router.get('/profile', exiger(P.configurer, P.voirRapports), async (req, res) => {
  const rows = await q('SELECT * FROM company_profile ORDER BY id LIMIT 1');
  res.json(rows[0]);
});
router.put('/profile', exiger(P.configurer), async (req, res) => {
  const champs = ['nom_entreprise', 'devise', 'telephone', 'telephone2', 'email',
    'adresse', 'rccm', 'ifu', 'autre_ref_fiscale', 'banque',
    'coordonnees_bancaires', 'message_pied', 'tva',
    'logo_path', 'cachet_path', 'signature_path'];
  const data = {};
  for (const c of champs) if (req.body[c] !== undefined) data[c] = req.body[c];
  const cols = Object.keys(data);
  if (cols.length) {
    await q(`UPDATE company_profile SET ${cols.map((c) => `${c} = ?`).join(', ')} WHERE id = 1`,
      cols.map((c) => data[c]));
  }
  res.json({ ok: true });
});

// ---------- Dashboard agrégé ----------
router.get('/dashboard', exiger(P.voirCaisse, P.voirRapports, P.vendre), async (req, res) => {
  const bt = req.query.boutique_id;
  const tx = await q(
    `SELECT type, SUM(montant) AS ca, SUM(marge) AS marge
     FROM transactions
     WHERE boutique_id = ? AND DATE_FORMAT(date_transaction, '%Y-%m') = DATE_FORMAT(CURDATE(), '%Y-%m')
     GROUP BY type`, [bt]);
  const jour = await q(
    `SELECT COALESCE(SUM(montant),0) AS ca_jour FROM transactions
     WHERE boutique_id = ? AND DATE(date_transaction) = CURDATE()`, [bt]);
  const solde = await q('SELECT * FROM v_soldes_caisse WHERE boutique_id = ?', [bt]);
  res.json({ caJour: jour[0].ca_jour, parType: tx, solde: solde[0] || null });
});

// ---------- Clôture mensuelle partenaire ----------
router.post('/partages/cloturer', exiger(P.cloturerMois), async (req, res) => {
  const { partenaire_id, boutique_id, mois } = req.body; // mois : 'AAAA-MM'
  const existe = await q('SELECT id FROM partages_mensuels WHERE partenaire_id = ? AND mois = ?',
    [partenaire_id, mois]);
  if (existe.length) return res.status(409).json({ erreur: 'Mois déjà clôturé' });
  const pts = await q('SELECT taux_partage FROM partenaires WHERE id = ?', [partenaire_id]);
  if (!pts.length) return res.status(404).json({ erreur: 'Partenaire introuvable' });
  const taux = Number(pts[0].taux_partage);
  const ventes = await q(
    `SELECT COALESCE(SUM(montant),0) AS total FROM transactions
     WHERE partenaire_id = ? AND type = 'forfait_hotspot'
       AND DATE_FORMAT(date_transaction, '%Y-%m') = ?`, [partenaire_id, mois]);
  const total = Number(ventes[0].total);
  const id = `pm_${Date.now()}`;
  await q(
    `INSERT INTO partages_mensuels
       (id, partenaire_id, boutique_id, mois, total_ventes, taux_partage,
        part_partenaire, part_entreprise, statut, valide_le, valide_par)
     VALUES (?,?,?,?,?,?,?,?, 'valide', NOW(), ?)`,
    [id, partenaire_id, boutique_id, mois, total, taux,
     total * taux, total * (1 - taux), req.user.id]);
  res.status(201).json({ id, total_ventes: total, part_partenaire: total * taux,
    part_entreprise: total * (1 - taux) });
});

// ---------- Documents commerciaux ----------
router.get('/documents', exiger(P.gererDocuments, P.voirRapports), async (req, res) => {
  const rows = await q('SELECT * FROM documents ORDER BY created_at DESC LIMIT 200');
  res.json(rows);
});
router.post('/documents', exiger(P.gererDocuments), async (req, res) => {
  const { boutique_id, type, client_nom, lignes = [], created_by } = req.body;
  const annee = new Date().getFullYear();
  const prefixe = { facture: 'FACT', devis_proforma: 'DEV',
    bon_commande: 'BC', ticket_caisse: 'TCK' }[type];
  if (!prefixe) return res.status(400).json({ erreur: 'Type invalide' });
  // Numérotation atomique (verrou ligne) : évite les doublons en concurrence
  await q(
    `INSERT INTO compteurs_documents (prefixe, annee, compteur) VALUES (?,?,1)
     ON DUPLICATE KEY UPDATE compteur = compteur + 1`, [prefixe, annee]);
  const cpt = await q('SELECT compteur FROM compteurs_documents WHERE prefixe = ? AND annee = ?',
    [prefixe, annee]);
  const numero = `${prefixe}-${annee}-${String(cpt[0].compteur).padStart(5, '0')}`;

  const profile = await q('SELECT tva FROM company_profile WHERE id = 1');
  const tauxTva = Number(profile[0].tva) / 100;
  const ht = lignes.reduce((s, l) => s + l.quantite * l.prix_unitaire, 0);
  const id = `doc_${Date.now()}`;
  await q(
    `INSERT INTO documents (id, boutique_id, type, numero, date_doc, client_nom,
       total_ht, tva, total_ttc, created_by)
     VALUES (?,?,?,?,NOW(),?,?,?,?,?)`,
    [id, boutique_id, type, numero, client_nom || '',
     ht, ht * tauxTva, ht * (1 + tauxTva), created_by || req.user.id]);
  for (const l of lignes) {
    await q(
      `INSERT INTO document_lignes (id, document_id, libelle, quantite, prix_unitaire)
       VALUES (?,?,?,?,?)`,
      [`dl_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`, id,
       l.libelle, l.quantite || 1, l.prix_unitaire || 0]);
  }
  res.status(201).json({ id, numero, total_ht: ht, total_ttc: ht * (1 + tauxTva) });
});

module.exports = router;
