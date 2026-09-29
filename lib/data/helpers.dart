/// Helpers partagés du Store (Phase 6) : purs, testés, sans état.
class StoreHelpers {
  const StoreHelpers._();

  /// Égalité de listes de chaînes (ordre significatif).
  static bool memeListe(List<String> a, List<String> b) =>
      a.length == b.length &&
      List.generate(a.length, (i) => a[i] == b[i]).every((e) => e);

  /// Égalité de libellés insensible casse/espaces (anti-doublon).
  static bool memeLibelle(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
