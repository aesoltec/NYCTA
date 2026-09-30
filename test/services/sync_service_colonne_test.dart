import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/services/sync_service.dart';

/// `SyncService` — resistance a une base non migree.
///
/// Regression : sur une base ou la colonne `date_ajout` n'existe pas encore,
/// PostgREST renvoie PGRST204 et le SyncService reessayait a l'identique
/// jusqu'a bloquer l'entree definitivement — la saisie hors-ligne etait
/// PERDUE. Or une colonne absente ne peut jamais reussir : il faut reessayer
/// une fois en ALLAGEANT le payload.
void main() {
  group('estColonneAbsente', () {
    test('reconnait le code PostgREST PGRST204', () {
      final e = Exception(
        "PostgrestException(message: Could not find the 'date_ajout' column "
        "of 'produits' in the schema cache, code: PGRST204, "
        "details: Bad Request, hint: null)",
      );
      expect(SyncService.estColonneAbsente(e), isTrue);
    });

    test('reconnait le code SQL 42703', () {
      final e = Exception(
        'column "date_ajout" of relation "produits" does not exist');
      expect(SyncService.estColonneAbsente(e), isTrue);
    });

    test('ne confond PAS une erreur metier avec une colonne absente', () {
      // Une violation RLS doit continuer a etre reessayee : la migration
      // ne la resolvra pas, mais c'est une autre cause, et la signaler
      // comme « colonne absente » ferait retirer un champ metier.
      final rls = Exception(
        'new row violates row-level security policy for table "produits"');
      expect(SyncService.estColonneAbsente(rls), isFalse);
    });

    test('une erreur reseau n est pas une colonne absente', () {
      expect(
        SyncService.estColonneAbsente(Exception('SocketException: failed')),
        isFalse,
      );
    });
  });

  group('sansColonnesOptionnelles', () {
    test('retire date_ajout et conserve le reste', () {
      final r = SyncService.sansColonnesOptionnelles({
        'id': 'p1',
        'libelle': 'Cable',
        'date_ajout': '2026-09-30T10:00:00Z',
      });
      expect(r.containsKey('date_ajout'), isFalse);
      expect(r['id'], 'p1');
      expect(r['libelle'], 'Cable');
    });

    test('laisse intact un payload sans colonne optionnelle', () {
      final src = {'id': 'p1', 'libelle': 'Cable'};
      final r = SyncService.sansColonnesOptionnelles(src);
      expect(r.length, src.length);
      expect(r, src);
    });

    test('ne touche pas a une colonne metier inconnue', () {
      final r = SyncService.sansColonnesOptionnelles({
        'id': 'p1',
        'quantite_stock': 3,
        'seuil_alerte': 2,
      });
      expect(r.containsKey('quantite_stock'), isTrue);
      expect(r.containsKey('seuil_alerte'), isTrue);
    });

    test('la liste des colonnes optionnelles est restreinte et documentee',
        () {
      // Retirer une colonne metier en silence masquerait une perte
      // d'information : seule date_ajout est aujourd'hui optionnelle.
      expect(SyncService.colonnesOptionnelles, ['date_ajout']);
    });
  });
}
