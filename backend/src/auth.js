const jwt = require('jsonwebtoken');
const config = require('./config');
const { q } = require('./db');
const { rolePermissions } = require('./permissions');

/** Middleware : vérifie le JWT et attache req.user. */
async function authentifie(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ erreur: 'Token manquant' });
  try {
    const payload = jwt.verify(token, config.jwt.secret);
    const users = await q('SELECT id, nom, role FROM users WHERE id = ? AND actif = 1', [payload.uid]);
    if (!users.length) return res.status(401).json({ erreur: 'Utilisateur invalide' });
    req.user = users[0];
    next();
  } catch {
    return res.status(401).json({ erreur: 'Token invalide ou expiré' });
  }
}

/** Middleware factory : exige une permission du rôle. */
const exiger = (...permissions) => (req, res, next) => {
  const possedees = rolePermissions[req.user.role] || [];
  const ok = permissions.some((p) => possedees.includes(p));
  if (!ok) return res.status(403).json({ erreur: 'Permission refusée' });
  next();
};

/** POST /api/auth/login → { token, user } */
async function login(req, res) {
  const { email, motDePasse } = req.body;
  if (!email || !motDePasse) {
    return res.status(400).json({ erreur: 'email et motDePasse requis' });
  }
  const users = await q(
    `SELECT u.*, GROUP_CONCAT(ub.boutique_id) AS boutique_ids
     FROM users u LEFT JOIN user_boutiques ub ON ub.user_id = u.id
     WHERE u.email = ? AND u.actif = 1 GROUP BY u.id`, [email]);
  if (!users.length) return res.status(401).json({ erreur: 'Identifiants invalides' });
  const u = users[0];
  const bcrypt = require('bcryptjs');
  const valide = await bcrypt.compare(motDePasse, u.password_hash);
  if (!valide) return res.status(401).json({ erreur: 'Identifiants invalides' });

  const token = jwt.sign({ uid: u.id, role: u.role }, config.jwt.secret,
    { expiresIn: config.jwt.expiresIn });
  res.json({
    token,
    user: {
      id: u.id, nom: u.nom, role: u.role,
      boutiqueIds: (u.boutique_ids || '').split(',').filter(Boolean),
    },
  });
}

module.exports = { authentifie, exiger, login };
