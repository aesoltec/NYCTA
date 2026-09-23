import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../services/backup_service.dart';

/// Sauvegardes & exports : vos données vous appartiennent.
/// - Exports CSV (Excel) : transactions et dépenses du mois
/// - Sauvegarde complète JSON (partageable WhatsApp/Drive, restaurable)
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegardes & exports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _Section(titre: '📤 Exports Excel (CSV)'),
          _Action(
            icone: Icons.table_chart_outlined,
            couleur: const Color(0xFF3E9D8F),
            titre: 'Transactions du mois',
            sousTitre:
                '${store.txBoutique.length} lignes · s\'ouvre dans Excel',
            onTap: () => BackupService.exporterTransactionsCsv(store),
          ),
          _Action(
            icone: Icons.money_off_outlined,
            couleur: const Color(0xFFD97706),
            titre: 'Dépenses du mois',
            sousTitre:
                '${store.depensesBoutique.length} lignes · s\'ouvre dans Excel',
            onTap: () => BackupService.exporterChargesCsv(store),
          ),
          const SizedBox(height: 16),
          _Section(titre: '💾 Sauvegarde complète'),
          _Action(
            icone: Icons.cloud_upload_outlined,
            couleur: const Color(0xFF3D6FB4),
            titre: 'Créer une sauvegarde',
            sousTitre:
                'Toutes les données en un fichier JSON — partagez-le sur '
                'WhatsApp Drive ou par mail',
            onTap: () => BackupService.sauvegardeComplete(store),
          ),
          _Action(
            icone: Icons.cloud_download_outlined,
            couleur: const Color(0xFF7E57C2),
            titre: 'Restaurer une sauvegarde',
            sousTitre:
                'Remplace les données actuelles par celles d\'un fichier '
                'de sauvegarde (nouveau téléphone, réparation…)',
            onTap: () async {
              final message = await BackupService.restaurer(store);
              if (message != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
          const SizedBox(height: 20),
          Card(
            color: const Color(0xFFFFF4E0),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '💡 Conseil : faites une sauvegarde complète chaque semaine et '
                'envoyez-la-vous sur WhatsApp. Avec Supabase configuré, la base '
                'est déjà sauvegardée dans le cloud — cette exportation couvre '
                'le mode local et sert de double sécurité.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  const _Section({required this.titre});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Action extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String titre, sousTitre;
  final Future<void> Function() onTap;
  const _Action({
    required this.icone,
    required this.couleur,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icone, color: couleur),
        ),
        title: Text(titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sousTitre,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          messenger.showSnackBar(const SnackBar(
              content: Text('⏳ Préparation du fichier…'),
              duration: Duration(seconds: 1)));
          await onTap();
        },
      ),
    );
  }
}
