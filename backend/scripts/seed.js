/* Crée le compte administrateur initial.
   Usage : npm run seed  (après avoir renseigné backend/.env) */
const bcrypt = require('bcryptjs');
const { q, pool } = require('../src/db');

async function main() {
  const nom = process.argv[2] || 'Administrateur';
  const email = process.argv[3] || 'admin@pme.local';
  const mdp = process.argv[4] || 'Admin123!';

  const hash = await bcrypt.hash(mdp, 10);
  await q(
    `INSERT INTO users (id, nom, email, password_hash, role, actif)
     VALUES (?, ?, ?, ?, 'admin', 1)
     ON DUPLICATE KEY UPDATE nom = VALUES(nom), password_hash = VALUES(password_hash)`,
    [`u_${Date.now()}`, nom, email, hash],
  );
  console.log(`✅ Admin créé : ${email} / ${mdp}  (CHANGEZ CE MOT DE PASSE)`);
  await pool.end();
}

main().catch((e) => { console.error(e); process.exit(1); });
