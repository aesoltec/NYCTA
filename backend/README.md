# API REST — PME Gestion (P6)

Backend Node.js + Express + MySQL2 + JWT. Servant `database/schema.sql`.

## Démarrage

```bash
# 1. Déployer la base (depuis la racine du projet)
mysql -u root -p < database/schema.sql

# 2. Configurer
cp .env.example .env   # ou renseigner .env : DB_*, JWT_SECRET…

# 3. Installer & lancer
npm install
npm run seed           # crée le compte admin (email/mdp en argument optionnel)
npm run dev            # http://localhost:3000/api
```

## Sécurité

- **JWT** obligatoire sur toutes les routes sauf `/api/auth/login`
- **Matrice de permissions côté serveur** (`src/permissions.js`) — miroir exact
  de celle du Flutter ; un caissier ne peut PAS appeler `/api/charges` en POST,
  même en forgeant la requête
- **Requêtes préparées** partout (anti-injection), colonnes en **liste blanche**
- Numérotation des documents **atomique** (`compteurs_documents` + `ON DUPLICATE KEY`)

## Endpoints principaux

| Méthode | Route | Permission | Description |
|---|---|---|---|
| POST | `/api/auth/login` | public | Connexion → JWT |
| GET/POST/PUT | `/api/transactions` | vendre | Journal complet |
| GET/POST/PUT | `/api/produits` | gererStock | Stock + photos |
| GET/POST/PUT | `/api/charges` | gererDepenses | Dépenses |
| GET/PUT | `/api/profile` | configurer | Identité, RCCM, IFU… |
| GET | `/api/dashboard?boutique_id=` | caisse/rapports | CA, marges, soldes |
| POST | `/api/partages/cloturer` | cloturerMois | Partage mensuel (anti-double) |
| POST | `/api/documents` | gererDocuments | Facture/devis/bon/ticket numéroté |
