import 'package:flutter/material.dart';
import '../../services/cloud_repository.dart';

/// Journal d'activité (v1.12) : qui a fait quoi, sur quelle table, quand —
/// alimenté par un trigger SQL sur chaque table métier. Réservé admin/gérant
/// (RLS "lecture journal").
class JournalActiviteScreen extends StatefulWidget {
  const JournalActiviteScreen({super.key});
  @override
  State<JournalActiviteScreen> createState() => _JournalActiviteScreenState();
}

class _JournalActiviteScreenState extends State<JournalActiviteScreen> {
  List<Map<String, dynamic>> _lignes = [];
  bool _charge = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final l = await CloudRepository.chargerJournalActivite();
    if (mounted) setState(() { _lignes = l; _charge = false; });
  }

  static const _couleurs = {
    'insert': Color(0xFF3E9D8F),
    'update': Color(0xFF3D6FB4),
    'delete': Color(0xFFD97706),
  };
  static const _icones = {
    'insert': Icons.add_circle_outline,
    'update': Icons.edit_outlined,
    'delete': Icons.delete_outline,
  };

  String _fmt(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal d\'activité')),
      body: _charge
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _charger,
              child: _lignes.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Aucune activité enregistrée',
                          style: TextStyle(color: Colors.grey))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _lignes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final l = _lignes[i];
                        final action = l['action']?.toString() ?? '';
                        final couleur = _couleurs[action] ?? Colors.grey;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [BoxShadow(
                                color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
                          ),
                          child: ListTile(
                            leading: Icon(_icones[action] ?? Icons.help_outline,
                                color: couleur),
                            title: Text(
                                '${l['table_nom'] ?? '?'} · ${action.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${l['user_nom'] ?? 'système'} · ${_fmt(l['created_at'])}'
                                '${l['ligne_id'] != null ? '\nid : ${l['ligne_id']}' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            isThreeLine: l['ligne_id'] != null,
                            onTap: () => showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                scrollable: true,
                                title: Text('${l['table_nom']} · $action'),
                                content: Text('${l['detail']}'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Fermer')),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
