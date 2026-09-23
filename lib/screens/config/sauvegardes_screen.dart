import 'package:flutter/material.dart';
import '../../core/env.dart';
import '../../services/backup_service.dart';
import '../../services/cloud_repository.dart';

/// Sauvegardes cloud de la base (migration v1.11) : snapshot complet en
/// JSONB côté Supabase, restaurable en 1 action. La restauration exige
/// le mot de passe système + la saisie du mot RESTAURER (opération
/// destructive : écrase toutes les données actuelles).
class SauvegardesScreen extends StatefulWidget {
  const SauvegardesScreen({super.key});
  static const motDePasse = 'WIZARD INSTALLER';

  @override
  State<SauvegardesScreen> createState() => _SauvegardesScreenState();
}

class _SauvegardesScreenState extends State<SauvegardesScreen> {
  List<Map<String, dynamic>> _liste = [];
  bool _charge = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final l = await CloudRepository.listeSauvegardes();
    if (mounted) setState(() { _liste = l; _charge = false; });
  }

  Future<bool> _verrou(String titre, {bool restauration = false}) async {
    if (!Env.supabaseConfigured) return false;
    final mdp = TextEditingController();
    final conf = restauration ? TextEditingController() : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // scrollable : sans ça, le contenu (avertissement + 2 champs en mode
        // restauration) déborde et se retrouve caché derrière le clavier sur
        // petit écran au lieu de défiler.
        scrollable: true,
        icon: Icon(restauration ? Icons.warning_amber_rounded : Icons.cloud_upload_outlined,
            color: restauration ? const Color(0xFFD97706) : const Color(0xFF3D6FB4)),
        title: Text(titre),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          if (restauration)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('⚠️ OPÉRATION DESTRUCTIVE : toutes les données '
                  'actuelles seront remplacées par cette sauvegarde.',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          TextField(controller: mdp, obscureText: true, autofocus: true,
              decoration: const InputDecoration(labelText: 'Mot de passe')),
          if (restauration) ...[
            const SizedBox(height: 10),
            TextField(controller: conf,
                decoration: const InputDecoration(
                    labelText: 'Tapez RESTAURER pour confirmer')),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              style: restauration
                  ? FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706))
                  : null,
              onPressed: () => Navigator.pop(ctx,
                  mdp.text.trim() == SauvegardesScreen.motDePasse &&
                  (!restauration || conf!.text.trim() == 'RESTAURER')),
              child: const Text('Confirmer')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _sauvegarder() async {
    if (!await _verrou('Sauvegarder toute la base ?')) return;
    setState(() => _busy = true);
    final r = await CloudRepository.sauvegarderBase();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r != null
              ? '✅ Sauvegarde créée (${r.$2} lignes)'
              : '❌ Échec — migration v1.11 exécutée ?')));
      await _charger();
    }
  }

  Future<void> _restaurer(Map<String, dynamic> s) async {
    if (!await _verrou('Restaurer la sauvegarde du '
        '${_fmt(s['created_at'])} ?', restauration: true)) {
      return;
    }
    setState(() => _busy = true);
    final r = await CloudRepository.restaurerBase(s['id'].toString());
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r ?? '❌ Échec de la restauration')));
    }
  }

  Future<void> _telecharger(Map<String, dynamic> s) async {
    setState(() => _busy = true);
    final json = await CloudRepository.telechargerSauvegarde(s['id'].toString());
    setState(() => _busy = false);
    if (json != null && mounted) {
      await BackupService.partagerFichier(
          'sauvegarde_${s['id'].toString().substring(0, 8)}.json', json);
    }
  }

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegardes de la base')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: _liste.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Aucune sauvegarde cloud',
                          style: TextStyle(color: Colors.grey))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      itemCount: _liste.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = _liste[i];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.cloud_done_outlined,
                                color: Color(0xFF3E9D8F)),
                            title: Text(_fmt(s['created_at']),
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${s['nb_lignes']} lignes · par ${s['auteur_nom']}',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  tooltip: 'Télécharger (JSON)',
                                  icon: const Icon(Icons.download_outlined, size: 19),
                                  onPressed: _busy ? null : () => _telecharger(s)),
                              IconButton(
                                  tooltip: 'Restaurer',
                                  icon: const Icon(Icons.settings_backup_restore,
                                      size: 19, color: Color(0xFFD97706)),
                                  onPressed: _busy ? null : () => _restaurer(s)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _sauvegarder,
        icon: _busy
            ? const SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_outlined),
        label: const Text('Sauvegarder la base'),
      ),
    );
  }
}
