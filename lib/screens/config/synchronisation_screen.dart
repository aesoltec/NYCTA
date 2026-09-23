import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';

/// Diagnostic de la file de synchronisation offline-first (SyncService).
///
/// Avant ce correctif, une opération refusée par le serveur (ex. politique
/// RLS, boutique non affectée à l'utilisateur) restait invisible : elle
/// semblait enregistrée à l'écran, puis disparaissait au redémarrage sans
/// aucun message d'erreur nulle part. Cet écran montre ce qui est en
/// attente, ce qui est bloqué, et pourquoi (message d'erreur du serveur).
class SynchronisationScreen extends StatelessWidget {
  const SynchronisationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synchronisation')),
      body: ListenableBuilder(
        listenable: SyncService(),
        builder: (context, _) {
          final sync = SyncService();
          final entrees = sync.detailFile;
          return RefreshIndicator(
            onRefresh: sync.synchroniser,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const _CarteIdentite(),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _Compteur(
                      valeur: sync.enAttente, libelle: 'En attente',
                      couleur: const Color(0xFF3D6FB4))),
                  const SizedBox(width: 12),
                  Expanded(child: _Compteur(
                      valeur: sync.enErreur, libelle: 'Bloquées',
                      couleur: const Color(0xFFC62828))),
                ]),
                const SizedBox(height: 16),
                if (sync.enErreur > 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer les opérations bloquées'),
                      onPressed: () async {
                        await sync.reessayerTout();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                  'Nouvelle tentative envoyée')));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Pour les entrées obsolètes (ex. capturées avant un
                  // correctif de bug) qui ne réussiront plus jamais :
                  // "Réessayer" ci-dessus les relance en boucle pour rien,
                  // celui-ci les efface définitivement sans les retenter.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828)),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Effacer les blocages (sans réessayer)'),
                      onPressed: () async {
                        final confirme = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Effacer les blocages ?'),
                            content: const Text(
                                'Les opérations bloquées seront supprimées '
                                'définitivement, sans être renvoyées au '
                                'serveur. À utiliser seulement si vous '
                                'savez qu\'elles sont obsolètes (ex. déjà '
                                'enregistrées autrement, ou datant d\'avant '
                                'un correctif).'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Annuler')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Effacer')),
                            ],
                          ),
                        );
                        if (confirme == true) {
                          await sync.viderErreurs();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text(
                                    'Blocages effacés')));
                          }
                        }
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (entrees.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      const Icon(Icons.cloud_done_outlined,
                          size: 32, color: Color(0xFF3E9D8F)),
                      const SizedBox(height: 8),
                      Text('Tout est synchronisé',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ]),
                  )
                else
                  for (final e in entrees)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: e['en_erreur'] == true
                                ? const Color(0xFFFFCDD2)
                                : const Color(0xFFE0E0E0)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Icon(
                              e['en_erreur'] == true
                                  ? Icons.error_outline
                                  : Icons.hourglass_top_outlined,
                              size: 18,
                              color: e['en_erreur'] == true
                                  ? const Color(0xFFC62828)
                                  : const Color(0xFF3D6FB4)),
                          const SizedBox(width: 8),
                          Text('${e['table']}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text('${e['essais'] ?? 0} essai(s)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ]),
                        if (e['cree_le'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Créée le ${e['cree_le']}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                        if (e['derniere_erreur'] != null) ...[
                          const SizedBox(height: 6),
                          Text('${e['derniere_erreur']}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828))),
                        ],
                      ]),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Carte d'identité de session : compare qui l'app CROIT être (rôle local)
/// avec qui le SERVEUR voit (user_role() via auth.uid()).
/// Si le rôle serveur est NULL/vide alors que l'app dit « admin », la
/// session Auth n'a aucune ligne public.users → user_role() vaut NULL et
/// TOUTES les écritures sont rejetées en 42501, puis les créations locales
/// sont écrasées au rechargement (créations « effacées au redémarrage »).
/// Le fix est alors côté base (créer la ligne users pour cet uid), pas
/// côté app.
class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite();

  Future<String> _roleServeur() async {
    final c = SupabaseService.client;
    if (c == null) return '— (mode local)';
    try {
      final r = await c.rpc<dynamic>('user_role');
      if (r == null) return 'NULL ⚠️';
      return r.toString();
    } catch (e) {
      return 'illisible ($e)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final session = SupabaseService.utilisateur;
    return FutureBuilder<String>(
      future: _roleServeur(),
      builder: (context, snap) {
        final roleSrv = snap.data ?? '…';
        final mismatch = snap.hasData &&
            SupabaseService.client != null &&
            (roleSrv == 'NULL ⚠️' || roleSrv == 'null' || roleSrv.isEmpty);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mismatch ? const Color(0xFFFDECEA) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: mismatch
                ? Border.all(color: const Color(0xFFC62828))
                : null,
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                      mismatch
                          ? Icons.warning_amber_rounded
                          : Icons.badge_outlined,
                      size: 18,
                      color: mismatch
                          ? const Color(0xFFC62828)
                          : const Color(0xFF3D6FB4)),
                  const SizedBox(width: 8),
                  const Text('Session & droits',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                SelectableText('UID session : ${session?.id ?? '— (non connecté)'}',
                    style: const TextStyle(fontSize: 12)),
                SelectableText('Email : ${session?.email ?? '—'}',
                    style: const TextStyle(fontSize: 12)),
                Text('Rôle vu par l\'app : ${store.role.name}'
                    '${store.profilCloudManquant ? '  ⚠️ (profil cloud manquant)' : ''}',
                    style: const TextStyle(fontSize: 12)),
                Text('Rôle vu par le serveur : $roleSrv',
                    style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: mismatch
                            ? const Color(0xFFC62828)
                            : Colors.black87)),
                if (mismatch) ...[
                  const SizedBox(height: 6),
                  const Text(
                      'Le serveur ne connaît pas ce compte : créez sa ligne '
                      'public.users (même id) avec le rôle admin, puis '
                      '« Réessayer les opérations bloquées ».',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFC62828))),
                ],
              ]),
        );
      },
    );
  }
}

class _Compteur extends StatelessWidget {
  final int valeur;
  final String libelle;
  final Color couleur;
  const _Compteur({required this.valeur, required this.libelle, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$valeur', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: couleur)),
        Text(libelle, style: TextStyle(fontSize: 12, color: couleur)),
      ]),
    );
  }
}
