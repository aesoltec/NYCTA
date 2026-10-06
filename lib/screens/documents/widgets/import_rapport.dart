import 'package:flutter/material.dart';

import '../../../services/document_import_service.dart';

/// Étape 2 : ce que l'import a compris, et ce qu'il n'a pas compris.
///
/// Le rapport est affiché EN ENTIER, même quand il est long : un
/// utilisateur qui voit « 197 documents, 3 anomalies » sans le détail
/// ne peut pas juger si l'import est fiable. C'est le cœur de la règle
/// « aucune perte silencieuse ».
class ImportRapport extends StatelessWidget {
  final ImportResultat rapport;
  final int importes;

  const ImportRapport({super.key, required this.rapport, this.importes = 0});

  @override
  Widget build(BuildContext context) {
    final r = rapport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: r.vide ? const Color(0xFFFDECEA) : const Color(0xFFEDF7ED),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.vide
                      ? 'Aucun document reconnu'
                      : '${r.documents.length} document(s) prêt(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '${r.documents.fold<int>(0, (s, d) => s + d.lignes.length)} '
                  'ligne(s) de détail',
                  style: const TextStyle(fontSize: 12),
                ),
                if (importes > 0) ...[
                  const SizedBox(height: 4),
                  Text('$importes déjà importé(s) en brouillon',
                      style: const TextStyle(fontSize: 12)),
                ],
                if (r.lignesIgnorees > 0) ...[
                  const SizedBox(height: 4),
                  Text('⚠ ${r.lignesIgnorees} ligne(s) ignorée(s)',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFC62828))),
                ],
              ],
            ),
          ),
        ),
        if (r.colonnesIgnorees.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Bloc(
            titre: 'Colonnes non utilisées',
            icone: Icons.help_outline,
            lignes: [
              for (final c in r.colonnesIgnorees)
                '« $c » — aucun champ correspondant',
            ],
          ),
        ],
        if (r.anomalies.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Bloc(
            titre: 'Anomalies (${r.anomalies.length})',
            icone: Icons.warning_amber_rounded,
            couleur: const Color(0xFFC62828),
            lignes: [
              for (final a in r.anomalies.take(40)) a.toString(),
              if (r.anomalies.length > 40)
                '… et ${r.anomalies.length - 40} autre(s)',
            ],
          ),
        ],
        if (!r.vide) ...[
          const SizedBox(height: 10),
          _ApercuDocuments(documents: r.documents),
        ],
      ],
    );
  }
}

class _Bloc extends StatelessWidget {
  final String titre;
  final IconData icone;
  final List<String> lignes;
  final Color? couleur;
  const _Bloc({
    required this.titre,
    required this.icone,
    required this.lignes,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: Icon(icone, color: couleur, size: 20),
          title: Text(titre,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: couleur)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final l in lignes)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(l,
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
}

class _ApercuDocuments extends StatelessWidget {
  final List<dynamic> documents;
  const _ApercuDocuments({required this.documents});

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.preview_outlined, size: 20),
          title: Text('Aperçu (${documents.length})',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final d in documents.take(20))
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${d.numero} · ${d.client} · ${d.type.titre} · '
                    '${d.lignes.length} ligne(s) · ${d.totalHT.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            if (documents.length > 20)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('… et ${documents.length - 20} autre(s)',
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
}