import 'package:flutter_test/flutter_test.dart';
import 'package:pme_gestion_pro/data/notifiers/fournisseur_notifier.dart';
import 'package:pme_gestion_pro/models/fournisseur.dart';

/// Phase 2 — FournisseurNotifier.
int _seq = 100;

FournisseurNotifier _notifier() =>
    FournisseurNotifier(genererId: () => 'fr${_seq++}');

void main() {
  group('FournisseurNotifier', () {
    test('ajouter : nom court + doublon refusés', () async {
      final n = _notifier();
      expect(
          await n.ajouterFournisseur(
              Fournisseur(id: '', nom: 'X')),
          'Nom trop court');
      expect(
          await n.ajouterFournisseur(
              Fournisseur(id: '', nom: 'ETS Fourni')),
          isNull);
      expect(
          await n.ajouterFournisseur(
              Fournisseur(id: '', nom: 'ets fourni')),
          'Ce fournisseur existe déjà');
    });

    test('champs conservés (spécialité, notes)', () async {
      final n = _notifier();
      await n.ajouterFournisseur(Fournisseur(
          id: '',
          nom: 'ETS Fourni',
          telephone: '0700',
          email: 'f@four.ci',
          specialite: 'Câbles',
          notes: 'Livraison rapide'));
      final f = n.fournisseurs.first;
      expect(f.specialite, 'Câbles');
      expect(f.notes, 'Livraison rapide');
      expect(f.id.startsWith('fr'), isTrue);
    });

    test('majFournisseur remplace', () async {
      final n = _notifier();
      await n.ajouterFournisseur(Fournisseur(id: '', nom: 'ETS'));
      final id = n.fournisseurs.first.id;
      await n.majFournisseur(Fournisseur(id: id, nom: 'ETS', notes: 'N'));
      expect(n.fournisseurs.first.notes, 'N');
    });

    test('majFournisseur inexistant → sans effet', () async {
      final n = _notifier();
      await n.majFournisseur(Fournisseur(id: 'zz', nom: 'X'));
      expect(n.fournisseurs, isEmpty);
    });

    test('supprimerFournisseur', () async {
      final n = _notifier();
      await n.ajouterFournisseur(Fournisseur(id: '', nom: 'ETS'));
      await n.supprimerFournisseur(n.fournisseurs.first.id);
      expect(n.fournisseurs, isEmpty);
      // Idempotent : inexistant sans effet.
      await n.supprimerFournisseur('zz');
    });
  });
}
