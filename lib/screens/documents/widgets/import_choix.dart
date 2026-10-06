import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../models/document.dart';
import '../../../services/document_import_service.dart';
import '../../../services/document_import_source.dart';

/// Étape 1 : type de document, taux de TVA, choix du fichier.
class ImportChoix extends StatefulWidget {
  final TypeDocument type;
  final double tvaPct;
  final String? fichier;
  final bool occupe;
  final ValueChanged<TypeDocument> onType;
  final ValueChanged<double> onTva;
  final ValueChanged<String?> onFichier;
  final VoidCallback onModele;
  final VoidCallback onAnalyser;

  const ImportChoix({
    super.key,
    required this.type,
    required this.tvaPct,
    required this.fichier,
    required this.occupe,
    required this.onType,
    required this.onTva,
    required this.onFichier,
    required this.onModele,
    required this.onAnalyser,
  });

  @override
  State<ImportChoix> createState() => _ImportChoixState();
}

class _ImportChoixState extends State<ImportChoix> {
  static const _source = DocumentImportSource();

  Future<void> _choisirFichier() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: DocumentImportSource.extensions,
      );
      if (picked.isEmpty) return;
      final chemin = picked.first.path;
      if (chemin == null) return;
      widget.onFichier(chemin);
    } catch (e) {
      _erreur('Sélection impossible : $e');
    }
  }

  /// Écrit le modèle vide dans un dossier choisi par l'utilisateur.
  ///
  /// `FilePicker.saveFile` passe par le SAF Android et renvoie un chemin
  /// que `dart:io` ne sait pas réécrire : on demande donc un DOSSIER, ce
  /// qui est fiable sur les quatre plateformes.
  Future<void> _ecrireModele() async {
    try {
      final dossier = await FilePicker.getDirectoryPath(
        dialogTitle: 'Dossier du modèle d’import',
      );
      if (dossier == null) return;
      final chemin = '$dossier${Platform.pathSeparator}modele_import.csv';
      File(chemin)
          .writeAsStringSync(DocumentImportService.modeleCsv());
      _erreur(null, info: 'Modèle écrit :\n$chemin');
    } catch (e) {
      _erreur('Modèle non écrit : $e');
    }
  }

  void _erreur(String? message, {String? info}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(info ?? message ?? ''),
      backgroundColor: message == null ? null : const Color(0xFFC62828),
      duration: Duration(seconds: message == null ? 6 : 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.fichier == null
        ? 'Aucun fichier sélectionné'
        : widget.fichier!.split(Platform.pathSeparator).last;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<TypeDocument>(
              initialValue: widget.type,
              decoration: const InputDecoration(labelText: 'Type par défaut'),
              items: [
                for (final t in TypeDocument.values)
                  DropdownMenuItem(value: t, child: Text(t.titre)),
              ],
              onChanged: (v) {
                if (v != null) widget.onType(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<double>(
              initialValue: widget.tvaPct,
              decoration: const InputDecoration(labelText: 'Taux de TVA (%)'),
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('0 %')),
                DropdownMenuItem(value: 18.0, child: Text('18 %')),
              ],
              onChanged: (v) {
                if (v != null) widget.onTva(v);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.occupe ? null : _choisirFichier,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Choisir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.occupe ? null : _ecrireModele,
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Modèle'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(nom, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    widget.occupe || widget.fichier == null ? null : widget.onAnalyser,
                icon: widget.occupe
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('Analyser le fichier'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}