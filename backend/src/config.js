require('dotenv').config();

module.exports = {
  port: parseInt(process.env.PORT || '3000', 10),
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306', 10),
    database: process.env.DB_NAME || 'pme_gestion',
    user: process.env.DB_USER || '',
    password: process.env.DB_PASSWORD || '',
    waitForConnections: true,
    connectionLimit: 10,
  },
  jwt: {
    // SÉCURITÉ : aucun secret par défaut. Le serveur REFUSE de démarrer
    // sans JWT_SECRET renseigné.
    secret: (() => {
      const s = process.env.JWT_SECRET;
      if (!s || s.length < 32) {
        console.error('❌ JWT_SECRET manquant ou trop court (32 car. min.). '
          + 'Renseignez-le dans backend/.env');
        process.exit(1);
      }
      return s;
    })(),
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },
  corsOrigin: process.env.CORS_ORIGIN || '*',
};
