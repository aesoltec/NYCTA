import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/store.dart';
import '../../core/validators.dart';
import '../../models/document.dart';
import '../../models/enums.dart';
import '../../services/document_service.dart';
import '../../widgets/date_selector.dart';
import 'document_preview_screen.dart';

/// Choix du type de document + client + lignes d'articles.
///
/// Deux modes :
/// - création : le document est généré puis prévisualisé ;
/// - édition ([docExistant]) : seul un BROUILLON peut être ouvert ici —
///   client, date et lignes sont pré-remplis, le type et le numéro sont
///   verrouillés, la sauvegarde passe par `Store.modifierDocument`.
class DocumentsScreen extends StatefulWidget {
  final DocumentBati? docExistant;
  const DocumentsScreen({super.key, this.docExistant});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  TypeDocument _type = TypeDocument.facture;
  final _client = TextEditingController();
  DateTime _date = DateTime.now();
  final List<LigneDoc> _lignes = [const LigneDoc(libelle: '', quantite: 1, prixUnitaire: 0)];

  bool get _enEdition => widget.docExistant != null;

  @override
  void initState() {
    super.initState();
    final doc = widget.docExistant;
    if (doc != null) {
      _type = doc.type;
      _client.text = doc.client;
      // Date illisible (ex. « non renseignée » d'un import) : aujourd'hui.
      _date = DocumentService.parseAffichage(doc.date) ?? DateTime.now();
      _lignes
        ..clear()
        ..addAll(doc.lignes);
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final devise = store.profile.devise;
    // Matrice documentaire (mission §2.9) : vendeur/caissier émettent
    // ticket, BL, facture simple et devis — JAMAIS de bon de commande
    // fournisseur (réservé achats/manager). En édition, le type est
    // verrouillé : changer le type changerait le préfixe de numéro et la
    // nature du document (bordereau ≠ facture), donc le justificatif.
    final typesAutorises = _enEdition
        ? [widget.docExistant!.type]
        : (store.role == Role.vendeur)
            ? TypeDocument.values
                .where((t) => t != TypeDocument.bonCommande)
                .toList()
            : TypeDocument.values;
    return Scaffold(
      appBar: AppBar(
          title: Text(_enEdition
              ? 'Modifier le document'
              : 'Documents commerciaux')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 5 types désormais (bordereau ajouté) : SegmentedButton débordait
          // sur petits écrans — pastilles défilantes, jamais d'overflow.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in typesAutorises)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(t.titre),
                      selected: _type == t,
                      onSelected: _enEdition
                          ? null
                          : (_) => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_enEdition)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  "Édition d'un brouillon : type et numéro verrouillés — le client, la date et les lignes peuvent changer. Les totaux sont recalcules à l'enregistrement.",
                  style:
                      TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            ),
          ChampDate(
            valeur: _date,
            label: "Date du document",
            onChanged: (d) => setState(() => _date = d),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _client,
            decoration: InputDecoration(
                labelText: _type == TypeDocument.bonCommande
                    ? 'Fournisseur' : 'Client',
                prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Flexible(
              child: Text('Articles',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Catalogue',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: () => _pickCatalogue(
                    context, (l) => setState(() => _lignes.add(l))),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () => setState(() => _lignes.add(
                  const LigneDoc(libelle: '', quantite: 1, prixUnitaire: 0))),
            ),
          ]),
          for (var i = 0; i < _lignes.length; i++)
            _LigneEditor(
              key: ValueKey(i),
              ligne: _lignes[i],
              devise: devise,
              sansPrix: _type.sansPrix,
              onChanged: (l) => setState(() => _lignes[i] = l),
              onSupprimer: _lignes.length > 1
                  ? () => setState(() => _lignes.removeAt(i))
                  : null,
            ),
          const SizedBox(height: 24),
          if (_type.sansPrix)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Norme : le bordereau ne comporte aucun prix — quantités, désignations et signatures uniquement.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: Icon(_enEdition
                  ? Icons.save_alt_outlined
                  : Icons.visibility_outlined),
              label: Text(_enEdition
                  ? 'Enregistrer les modifications'
                  : 'Générer le document'),
              onPressed: _enEdition
                  ? () => _enregistrerModif(context, store)
                  : () {
                      final valides = _lignes
                          .where((l) =>
                              l.libelle.trim().isNotEmpty &&
                              l.quantite > 0 &&
                              (_type.sansPrix || l.prixUnitaire > 0))
                          .toList();
                      if (valides.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ajoutez au moins un article valide')));
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => DocumentPreviewScreen(
                          type: _type,
                          client: _client.text.trim(),
                          lignes: valides,
                          date: _date,
                        ),
                      ));
                    },
            ),
          ),
        ],
      ),
    );
  }

  /// Sauvegarde de l'édition d'un BROUILLON : le type et le numéro ne
  /// changent pas ; client, date et lignes sont remplacés et les totaux
  /// recalcules au taux du profil (un total incohérent serait une
  /// facture fausse). Le statut reste brouillon : c'est la validation
  /// manager qui le passe à émis — un document émis, lui, ne se
  /// modifie jamais (voir `DocumentNotifier.modifierDocument`).
  Future<void> _enregistrerModif(BuildContext context, Store store) async {
    final doc = widget.docExistant!;
    if (_client.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le client est requis')));
      return;
    }
    final valides = _lignes
        .where((l) =>
            l.libelle.trim().isNotEmpty &&
            l.quantite > 0 &&
            (_type.sansPrix || l.prixUnitaire > 0))
        .toList();
    if (valides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoutez au moins un article valide')));
      return;
    }
    final erreur = await store.modifierDocument(
      doc.copyWith(
        client: _client.text.trim(),
        date: formatDateCourt(_date),
        lignes: valides,
      ),
      tvaPct: store.profile.tva,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(erreur == null ? '✅ Document modifié' : '⚠️ $erreur')));
    if (erreur == null) {
      Navigator.of(context).pop();
    }
  }

  /// Sélecteur d'article dans le catalogue tarifaire.
  static Future<void> _pickCatalogue(
      BuildContext context, ValueChanged<LigneDoc> onChanged) async {
    final store = context.read<Store>();
    final recherche = TextEditingController();
    await showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        final tarifs = store.tarifsActifs
            .where((t) => t.libelle.toLowerCase()
                .contains(recherche.text.toLowerCase()))
            .toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text('Choisir dans le catalogue',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: recherche,
                decoration: const InputDecoration(
                    hintText: 'Rechercher…', prefixIcon: Icon(Icons.search)),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 8),
              if (tarifs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Catalogue vide — ajoutez des articles dans '
                      '« Plus → Tarifs & catalogue ».',
                      style: TextStyle(color: Colors.grey)),
                )
              else
                for (final t in tarifs)
                  ListTile(
                    dense: true,
                    title: Text(t.libelle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(t.categorie,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                    trailing: Text(
                        '${t.prix.toStringAsFixed(0)} ${store.profile.devise}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      onChanged(LigneDoc(
                          libelle: t.libelle, quantite: 1, prixUnitaire: t.prix));
                      Navigator.pop(ctx);
                    },
                  ),
            ]),
        );
      }),
    );
  }
}

class _LigneEditor extends StatelessWidget {
  final LigneDoc ligne;
  final String devise;
  final bool sansPrix;
  final ValueChanged<LigneDoc> onChanged;
  final VoidCallback? onSupprimer;
  const _LigneEditor({
    super.key, required this.ligne, required this.devise,
    this.sansPrix = false,
    required this.onChanged, this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        TextFormField(
          initialValue: ligne.libelle,
          decoration: const InputDecoration(labelText: 'Libellé'),
          onChanged: (v) => onChanged(LigneDoc(
              libelle: v, quantite: ligne.quantite, prixUnitaire: ligne.prixUnitaire)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: ligne.quantite == 0 ? '' : '${ligne.quantite}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qté'),
              validator: (v) => V.entier(v, min: 1, label: 'Qté'),
              onChanged: (v) => onChanged(LigneDoc(
                  libelle: ligne.libelle,
                  quantite: int.tryParse(v) ?? 0,
                  prixUnitaire: ligne.prixUnitaire)),
            ),
          ),
          const SizedBox(width: 10),
          if (!sansPrix)
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: ligne.prixUnitaire == 0 ? '' : ligne.prixUnitaire.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Prix unit. ($devise)'),
                onChanged: (v) => onChanged(LigneDoc(
                    libelle: ligne.libelle,
                    quantite: ligne.quantite,
                    prixUnitaire: double.tryParse(v.replaceAll(' ', '')) ?? 0)),
              ),
            ),
          if (onSupprimer != null)
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: onSupprimer),
        ]),
      ]),
    );
  }
}
