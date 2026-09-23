const { q } = require('./db');

/**
 * Fabrique un routeur CRUD minimal et sécurisé.
 * config = { table, idColonne, champs: [colonnes écrites], permissionLecture,
 *            permissionEcriture }
 * Sécurité : colonnes en liste blanche — jamais de SQL dynamique sauvage.
 */
function crud(config) {
  const { table, idColonne, champs, permissionLecture, permissionEcriture } = config;

  return {
    /** GET / — liste (filtrable par ?boutique_id=) */
    async liste(req, res) {
      const where = req.query.boutique_id ? 'WHERE boutique_id = ?' : '';
      const params = req.query.boutique_id ? [req.query.boutique_id] : [];
      const rows = await q(`SELECT * FROM ${table} ${where} ORDER BY created_at DESC LIMIT 500`, params);
      res.json(rows);
    },

    /** GET /:id */
    async detail(req, res) {
      const rows = await q(`SELECT * FROM ${table} WHERE ${idColonne} = ?`, [req.params.id]);
      if (!rows.length) return res.status(404).json({ erreur: 'Introuvable' });
      res.json(rows[0]);
    },

    /** POST / — création (id généré côté client : UUID) */
    async creer(req, res) {
      const data = {};
      for (const c of champs) if (req.body[c] !== undefined) data[c] = req.body[c];
      if (!data[idColonne]) data[idColonne] = req.body.id || `${Date.now()}`;
      const cols = Object.keys(data);
      await q(
        `INSERT INTO ${table} (${cols.join(',')}) VALUES (${cols.map(() => '?').join(',')})`,
        cols.map((c) => data[c]),
      );
      res.status(201).json({ id: data[idColonne] });
    },

    /** PUT /:id */
    async maj(req, res) {
      const data = {};
      for (const c of champs) if (req.body[c] !== undefined) data[c] = req.body[c];
      const cols = Object.keys(data);
      if (!cols.length) return res.status(400).json({ erreur: 'Rien à modifier' });
      await q(
        `UPDATE ${table} SET ${cols.map((c) => `${c} = ?`).join(', ')} WHERE ${idColonne} = ?`,
        [...cols.map((c) => data[c]), req.params.id],
      );
      res.json({ ok: true });
    },
  };
}

module.exports = { crud };
