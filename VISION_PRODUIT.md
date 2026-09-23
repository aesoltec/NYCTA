# 🚀 VISION PRODUIT — De la gestion de PME à la plateforme d'entreprise

> Document stratégique — horizons H1 (0-6 mois) / H2 (6-18 mois) / H3 (18-36 mois).
> Statuts : ⬜ pas démarré · 🟡 en réflexion · ✅ dans le périmètre actuel

---

## 1. Modernisation technique (socle)

| # | Évolution | Horizon | Justification |
|---|---|---|---|
| 1.1 | **Architecture multi-tenant** (tenant_id = entreprise, isolation RLS) | H2 | Prérequis absolu du SaaS : une base, N entreprises clientes |
| 1.2 | Riverpod ou Bloc à la place de Provider | H1 | État plus testable, granularité, évite les rebuilds inutiles à grande échelle |
| 1.3 | Codegen : freezed + json_serializable + drift | H1 | Modèles immuables, sérialisation sans erreur, DB locale typée |
| 1.4 | **CI/CD** (GitHub Actions : analyse → tests → build APK/AAB → Firebase App Distribution) | H1 | Livraison continue, bêta-testeurs automatiques |
| 1.5 | Tests métier (règles de calcul) + golden tests UI + intégration Supabase émulée | H1 | Confiance pour refactorer en croissance |
| 1.6 | Flavors (dev/staging/prod) + fvm (version Flutter figée) | H1 | Zéro « ça marche chez moi » |
| 1.7 | Observabilité : Crashlytics + Analytics + Sentry | H1 | Savoir ce qui plante chez les clients sans qu'ils appellent |
| 1.8 | Modularisation (package internes : core, caisse, stock, finance…) | H2 | Équipes multiples sans conflits |
| 1.9 | Web dashboard (Flutter Web) + tablette POS paysage | H2 | Le gérant veut un écran large ; le caissier une tablette |
| 1.10 | Background isolates pour sync lourde | H2 | Sync de 10 000 lignes sans figer l'UI |

## 2. Fonctionnalités entreprise (le cœur de l'ambition)

### A. Gouvernance & contrôle
- **Audit trail complet** : qui a fait quoi, quand, avant/après (immuabilité horodatée) — exigence n°1 des grands comptes
- **Workflows de validation** : seuil de remise → validation gérant ; dépense > X → validation direction
- **RBAC granulaire** : rôles customs, permissions à la case, délégations temporaires
- **Multi-entité / consolidation** : groupe de sociétés, rapports consolidés, éliminations internes
- **SSO / SAML / OTP** pour les directions

### B. Cycle complet de l'entreprise
- **Achats & fournisseurs** : bons de commande → réception → facture fournisseur (3-way match) → paiement
- **Réapprovisionnement prédictif** : seuils dynamiques selon vélocité de vente
- **Inventaire avancé** : codes-barres/QR scan, emplacements, transferts inter-boutiques, inventaire tournant
- **Paie & RH** : bulletins, avances, congés, pointage
- **Immobilisations & amortissements**
- **CRM** : clients, devis, relances automatiques par WhatsApp
- **Comptabilité** : exports journal/OD (Sage, Wave, QuickBooks), plan comptable paramétrable, clôtures mensuelles/annuelles

### C. Finance avancée
- **Multi-devises** (FCFA + USD + EUR) avec taux de change journaliers
- **Budgets analytiques** par activité/entité/mois avec alertes et verrous
- **Trésorerie prévisionnelle** : engagement → besoin à J+30/J+60
- **Facturation électronique** conforme (normes OHADA/SYSCOHADA révisé, DGI électronique)
- **Crédit client** : plafonds, encours, relances automatiques

### D. Mobile Money industrialisé
- Intégration agrégateurs (**CinetPay, PayDunya, Orange Money API, Wave, Djamo**) : transactions auto-réconciliées
- **Orchestrateur de paiements** : file, retry, états, rapprochement quotidien
- Alertes solde agences en temps réel

### E. Intelligence artificielle (différenciation majeure)
| Cas d'usage | Valeur |
|---|---|
| **Prévision de ventes** (30/60/90 jours par activité) | Anticipe le cash et le stock |
| **OCR des factures fournisseurs** | Saisie d'une dépense en photo → tout est rempli |
| **Détection d'anomalies/fraude** (écart caisse, transactions hors normes) | Protège le dirigeant |
| **Réapprovisionnement intelligent** | « Commandez 20 câbles RJ45 avant jeudi » |
| **Assistant conversationnel** (« Quel est mon CA de la semaine ? », « Quels partenaires ne vendent pas ? ») | Décision en langage naturel |
| **Scoring partenaires hotspot** | Identifie les partenaires à fort potentiel |

### F. Réseau & écosystème (le vrai levier d'échelle)
- **Marketplace de partenaires hotspot** : un partenaire s'inscrit, reçoit son hotspot, vend, se fait payer automatiquement sa part à la clôture — **réseau national de revendeurs sans salariés**
- **API publique + webhooks** : les développeurs branchant leurs outils dessus = effet plateforme
- **Portail client** : vos clients consultent leurs devis/factures en ligne et paient par MoMo
- **Mode white-label** : revendeurs revendant l'app sous leur marque

## 3. Sécurité, conformité, exploitation à l'échelle

- Chiffrement au repos et en transit, secrets dans un coffre (Doppler/Vault)
- Sauvegardes **PITR** (restauration à la minute), plans de reprise testés
- Pentest annuel, bug bounty, SOC 2 (si marché international)
- Conformité fiscale locale paramétrable par pays (Côte d'Ivoire, Sénégal, Bénin, Burkina…)
- SLAs : 99,9 % de disponibilité cible, support N1/N2

## 4. Modèle économique d'ambition

| Pilier | Mécanique |
|---|---|
| **SaaS par abonnement** | Gratuit (1 boutique) / Pro ~10 000 FCFA/mois / Entreprise sur devis — par boutique, par utilisateur |
| **Commission marketplace** | 3-5 % sur les ventes de forfaits transitant par le réseau |
| **Fintech** : avance de trésorerie sur historique de ventes (scoring interne) | Marge financière |
| **Services** : paramétrage, formation, support premium | Recette complémentaire |
| **Données (agrégées, anonymisées)** : indices de consommation tech en Afrique de l'Ouest | Option long terme |

## 5. Feuille de route synthétique

- **H1 (0-6 mois)** : industrialiser le socle (CI/CD, tests, codegen, flavors, observabilité) + achats/fournisseurs + scan codes-barres. *Objectif : 10-20 PME clientes payantes.*
- **H2 (6-18 mois)** : multi-tenant, web dashboard, workflows, audit trail, intégration MoMo, OCR factures. *Objectif : 100-300 entreprises, 1er pays supplémentaire.*
- **H3 (18-36 mois)** : marketplace partenaires, IA prédictive, API publique, multi-pays, white-label, SSO. *Objectif : la référence de la gestion PME tech en Afrique de l'Ouest francophone.*

## 6. Équipe cible à l'échelle

1 PM + 2-3 développeurs Flutter/backend + 1 DevOps (partagé) + 1 support/commercial terrain + comptable partenaire pour la conformité. Démarrage possible à 2 personnes avec ce socle.
