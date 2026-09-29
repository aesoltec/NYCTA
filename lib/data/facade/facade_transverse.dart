// Ignore_for_file: unnecessary_import

import '../../core/constants.dart';
import '../store.dart';

/// Lectures transverses partagées par `StoreSerializer`, `CloudLoader` et
/// les autres façades. Dart ne résout PAS une extension depuis une autre
/// bibliothèque : ces lectures vivent donc dans une extension dédiée,
/// ré-exportée par `store.dart` (donc visibles partout).
extension StoreTransverse on Store {
  List<String> get catsProduit => categories.catsProduit;
  List<String> get catsCharge => categories.catsCharge;
  List<String> get opsMobileMoney => categories.opsMobileMoney;
  List<String> get opsCredit => categories.opsCredit;
  List<String> get domainesPresta => categories.domainesPresta;
  List<String> get dureesForfaitListe => categories.dureesForfaitListe;
  String get moisCourant => C.moisKey(DateTime.now());
}
