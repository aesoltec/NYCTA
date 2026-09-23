/// Validateurs centralisés — RÈGLE PROJET : aucun champ de saisie sans
/// validation. Chaque validateur couvre : vide, format (regex), plage.
/// Les champs numériques DOIVENT avoir un clavier numérique côté UI.
class V {
  static final _prixRe = RegExp(r'^\d+([.,]\d{1,2})?$');
  static final _entierRe = RegExp(r'^\d+$');
  static final _telRe = RegExp(r'^\+?\d[\d\s.\-]{7,17}$');
  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$');

  /// Prix / montant : regex + strictement positif. Clavier : number.
  static String? prix(String? v, {String label = 'Montant'}) {
    final s = (v ?? '').trim().replaceAll(' ', '');
    if (s.isEmpty) return '$label requis';
    if (!_prixRe.hasMatch(s)) return '$label invalide (ex : 2500 ou 2500.50)';
    if (double.parse(s.replaceAll(',', '.')) <= 0) return '$label doit être > 0';
    return null;
  }

  static double prixValue(String v) =>
      double.parse(v.trim().replaceAll(' ', '').replaceAll(',', '.'));

  /// Entier ≥ min. Clavier : number.
  static String? entier(String? v, {int min = 0, String label = 'Valeur'}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$label requis';
    if (!_entierRe.hasMatch(s)) return '$label : entier invalide';
    if (int.parse(s) < min) return '$label doit être ≥ $min';
    return null;
  }

  /// Entier optionnel : vide = null (l'appelant applique son défaut).
  /// Sert aux champs non obligatoires comme le seuil d'alerte.
  static int? entierOpt(String? v, {int min = 0, String label = 'Valeur'}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (!_entierRe.hasMatch(s)) return null; // l'appelant validera via entier()
    final n = int.parse(s);
    if (n < min) return null;
    return n;
  }

  /// Validateur pour entier optionnel : vide = OK, sinon entier ≥ min.
  static String? entierFacultatif(String? v, {int min = 0, String label = 'Valeur'}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return entier(s, min: min, label: label);
  }
  /// Pourcentage 0..100 (regex décimale acceptée). Clavier : number.
  static String? pourcent(String? v, {String label = 'Pourcentage'}) {
    final s = (v ?? '').trim().replaceAll(' ', '');
    if (s.isEmpty) return '$label requis';
    if (!_prixRe.hasMatch(s)) return '$label invalide';
    final n = double.parse(s.replaceAll(',', '.'));
    if (n < 0 || n > 100) return '$label entre 0 et 100';
    return null;
  }

  /// Téléphone optionnel : si saisi, doit être plausible (8-18 chiffres).
  static String? telephone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // optionnel
    if (!_telRe.hasMatch(s)) return 'Téléphone invalide (ex : 07 08 09 10 11)';
    return null;
  }

  /// Email : requis et formaté.
  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email requis';
    if (!_emailRe.hasMatch(s)) return 'Email invalide (ex : nom@domaine.com)';
    return null;
  }

  /// Email optionnel.
  static String? emailOpt(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return email(s);
  }

  /// Texte libre : longueur minimale.
  static String? texte(String? v, int min, String label) {
    final s = (v ?? '').trim();
    if (s.length < min) return '$label requis ($min caractères min.)';
    return null;
  }
}
