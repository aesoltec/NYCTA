const express = require('express');
const cors = require('cors');
const config = require('./config');
const routes = require('./routes');

const app = express();
app.use(cors({ origin: config.corsOrigin }));
app.use(express.json({ limit: '2mb' }));

app.get('/health', (req, res) => res.json({ statut: 'ok', heure: new Date() }));
app.use('/api', routes);

// Gestion centralisée des erreurs (jamais de stacktrace en production)
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ erreur: 'Erreur interne' });
});

app.listen(config.port, () => {
  console.log(`✅ API PME Gestion sur http://localhost:${config.port}/api`);
});
