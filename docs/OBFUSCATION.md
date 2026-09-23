# 🔒 Obfuscation & durcissement du build

## Ce qui est appliqué

| Couche | Technique | Commande / fichier |
|---|---|---|
| Dart | Obfuscation identifiants + split debug info | `--obfuscate --split-debug-info=build/symbols` |
| Android | R8 minification + shrinking + obfuscation Java | `android/proguard-rules.pro` (livré) |
| Android | Ressources réduites | `--shrink` |
| iOS | Symboles retirés (release natif, par défaut) | `flutter build ios --release` |

## Build obfusqué

```bash
# Linux / macOS
bash build/obfusquer.sh

# Windows
build\obfusquer.bat
```

Sorties : APK par ABI (`app-armeabi-v7a-release.apk` etc. — distribuables par
WhatsApp/Drive) + AAB (Play Store éventuelle).

## ⚠️ Les symboles de debug (`build/symbols/`) sont SECRETS

Ils permettent de **dé-obfusquer** les crashs. Gardez-les privés et uploadez-les
vers votre outil de monitoring (Sentry/Crashlytics) — jamais dans le dépôt,
jamais partagés. Sans eux, un crash en production sera illisible.

## Ce que l'obfuscation protège — et ne protège PAS

✅ **Protège contre** : la rétro-ingénierie aisée (lecture du code, noms de
classes/variables, logique métier), la modification simple et le re-signage
opportuniste.

❌ **Ne protège PAS contre** : un attaquant déterminé avec débogueur natif,
ni la lecture des secrets **présents dans le binaire** :

- la clé anon Supabase est **publique par conception** (la sécurité est le RLS)
- le mot de passe `WIZARD INSTALLER` reste lisible dans l'APK → il verrouille
  une page d'installation, rien de plus ; la garde réelle reste côté serveur
  (RLS + garde admin de `installer_etape`)

**Règle d'or inchangée : aucun secret réel (service_role, JWT_SECRET, mots de
passe comptes) ne doit JAMAIS être embarqué dans l'application.**

## Anti-repackage (signature)

Le build release est signé par votre keystore (`android/app/upload-keystore.jks`
à créer — voir `key.properties`). Google Play App Signing (si Play Store) ou la
vérification de signature côté serveur complètent la protection. Le projet
fournit le `.gitignore` adapté (`key.properties` et `upload-keystore.jks` exclus).

## Vérification après build

```bash
# L'APK obfusqué ne doit plus contenir les noms Dart lisibles :
unzip -p build/app/outputs/flutter-apk/app-release.apk libapp.so | strings | grep -i "PME Gestion" || echo "✅ obfusqué"
```

## ⚠️ Le `.env` n'est JAMAIS protégé par l'obfuscation

L'APK est un ZIP : `assets/flutter_assets/.env` se lit **en clair** après
décompression, obfuscation ou non. `--obfuscate` renomme les identifiants
Dart ; il ne chiffre aucun asset.

RÈGLE ABSOLUE pour le `.env` embarqué dans l'application mobile :
- ✅ autorisé : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`
  (valeurs publiques par conception — la sécurité = RLS, pas la clé)
- 🔴 INTERDIT : `SERVICE_ROLE_KEY`, `DB_PASSWORD`, `JWT_SECRET`,
  secrets Mobile Money → vivent UNIQUEMENT côté serveur (backend/.env,
  jamais dans l'app, jamais dans un asset, jamais dans le code Dart)

Le seul `.env` qui peut contenir des secrets est celui du **serveur**,
jamais embarqué dans le binaire mobile.

## ⚠️ `env.dart` n'est pas plus protégé que `.env`

`--obfuscate` renomme les identifiants (classes, variables) mais conserve
les littéraux chaîne en clair dans `libapp.so` — ils sont requis à
l'exécution. Extraction contre un APK obfusqué :

    unzip -p app-release.apk lib/arm64-v8a/libapp.so | strings | grep "eyJ"

→ la valeur est lue en ~10 secondes. Un passage de `flutter_dotenv` à des
constantes `env.dart` est acceptable pour la maintenabilité (config publique
uniquement), jamais comme mesure de sécurité. Même règle : uniquement des
valeurs publiques (URL, clé anon) ; les secrets restent côté serveur.

## 🔑 Sécuriser la clé ANON (elle est publique par conception)

On ne la cache pas (lisible dans l'APK, c'est normal) — on réduit ce
qu'elle peut faire :

1. RLS sur 100 % des tables + verifier_installation.sql après chaque migration
2. revoke all on all tables/sequences/functions in schema public from anon
   + grant usage on schema public to anon
   (l'app exige une session → le rôle "authenticated" suffit)
3. revoke execute sur installer_etape / charger_donnees_test /
   cloturer_partage / prochain_numero from anon
4. Projets Supabase séparés dev/prod ; rotation Settings → API en cas d'abus
5. Logs Supabase activés pour la détection d'abus
6. Étape ultime : clés API à périmètre réduit ou Edge Functions (service_role
   côté serveur) pour les opérations sensibles

SERVICE_ROLE : interdite dans l'app, le dépôt et tout client — serveur uniquement.

## 📷 Images & QR codes — threat model

Aujourd'hui : aucun décodeur QR dans l'app — un QR photographié est inerte
(pixels jamais lus). Pipeline image_picker : décodage natif → re-compression
JPEG ≤1200px → copie locale → affichage. Une image malformée plante au pire
l'écran courant (ErrorWidget gris, app protégée).

SI un scanner QR est ajouté un jour : traiter le contenu comme une entrée
hostile — jamais vers launchUrl sans allowlist de domaines, jamais de code
dynamique, validation regex + dialogue de confirmation avant toute action,
allowed_mime_types image/jpeg+png sur le bucket.
