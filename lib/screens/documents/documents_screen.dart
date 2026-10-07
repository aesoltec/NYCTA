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

  /// Motif de modification — obligatoire sur un document ÉMIS
  /// (`DocumentBati.exigeMotifModification`), libre sur un brouillon.
  final _motif = TextEditingController();
  final _note = TextEditingController();
  final _adresseLivraison = TextEditingController();
  int _delaiPaiement = 0;

  bool get _enEdition => widget.docExistant != null;

  /// Un document émis modifiable exige un motif : on le dit AVANT, dans
  /// le bandeau, plutôt que de le faire échouer à l'enregistrement.
  bool get _motifExige => _enEdition && widget.docExistant!.exigeMotifModification;

  /// Échéance = date du document + délai de règlement. Une facture
  /// payable le 12 pour 30 jours arrive le 12, pas le 11 du mois
  /// suivant : on calcule en jours, pas en mois.
  DateTime _echeance() => _date.add(Duration(days: _delaiPaiement));

  @override
  void initState() {
    super.initState();
    final doc = widget.docExistant;
    if (doc != null) {
      _type = doc.type;
      _client.text = doc.client;
      // Date illisible (ex. « non renseignée » d'un import) : aujourd'hui.
      _date = DocumentService.parseAffichage(doc.date) ?? DateTime.now();
      _note.text = doc.note;
      _adresseLivraison.text = doc.adresseLivraison;
      _delaiPaiement = doc.delaiPaiementJours;
      _lignes
        ..clear()
        ..addAll(doc.lignes);
    }
  }

  @override
  void dispose() {
    _client.dispose();
    _motif.dispose();
    _note.dispose();
    _adresseLivraison.dispose();
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
          // Adresse de livraison : pertinente surtout au bordereau, où
          // la marchandise est rarement livrée à l'adresse de
          // facturation. Optionnel partout ailleurs.
          const SizedBox(height: 12),
          TextFormField(
            controller: _adresseLivraison,
            decoration: const InputDecoration(
              labelText: 'Adresse de livraison (si différente)',
              prefixIcon: Icon(Icons.local_shipping_outlined),
            ),
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
          // Conditions de règlement + note libre : information utile au
          // client, et source du suivi des impayés. Sur un bordereau
          // (sans prix) un délai n'a aucun sens -> masqué.
          if (!_type.sansPrix) ...[
            const SizedBox(height: 16),
            // Plein largeur, PAS dans un `Row` : `DropdownButtonFormField`
            // interpose un `RepaintBoundary`, donc un `Expanded` autour
            // de lui n'a pas de `Flex` pour parent -> « Incorrect use of
            // ParentDataWidget ».
            DropdownButtonFormField<int>(
              initialValue: _delaiPaiement,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Conditions de paiement'),
              // Bornes usuelles : comptant 0, puis 15/30/45/60 jours.
              items: const [
                DropdownMenuItem(value: 0, child: Text('Comptant')),
                DropdownMenuItem(value: 15, child: Text('15 jours')),
                DropdownMenuItem(value: 30, child: Text('30 jours')),
                DropdownMenuItem(value: 45, child: Text('45 jours')),
                DropdownMenuItem(value: 60, child: Text('60 jours')),
              ],
              onChanged: (v) => setState(() => _delaiPaiement = v ?? 0),
            ),
            if (_delaiPaiement > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Échéance : ${formatDateCourt(_echeance())}',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note / conditions (imprimée en pied)',
              hintText: 'Ex. Paiement à 30 jours, marchandise vérifiée…',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 8),
          if (_motifExige)
            TextFormField(
              controller: _motif,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motif de modification (obligatoire)',
                hintText: 'Ex. erreur de quantité saisie à la livraison',
                prefixIcon: Icon(Icons.history_toggle_off_outlined),
              ),
            ),
          const SizedBox(height: 20),
          for (var i = 0; i < _lignes.length; i++)
            _LigneEditor(
              key: ValueKey(i),
              ligne: _lignes[i],
              devise: devise,
              sansPrix: _type.sansPrix,
              onChanged: (l) => setState(() => _lignes[i] = l),
              // Le retrait est possible même sur la DERNIERE ligne : la
              // ligne vide restante est ignorée à l'enregistrement (elle
              // n'a ni libellé, ni quantité). Sans cela, un document
              // d'une seule ligne ne pouvait pas être vidé — l'utilisateur
              // se retrouvait bloqué sans comprendre pourquoi.
              onSupprimer: () => setState(() {
                _lignes.removeAt(i);
                if (_lignes.isEmpty) {
                  _lignes.add(const LigneDoc(
                      libelle: '', quantite: 1, prixUnitaire: 0));
                }
              }),
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
                          note: _note.text.trim(),
                          adresseLivraison: _adresseLivraison.text.trim(),
                          delaiPaiementJours: _delaiPaiement,
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
    if (_motifExige && _motif.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Motif de modification obligatoire : un document émis reste traçable')));
      return;
    }
    final erreur = await store.modifierDocument(
      doc.copyWith(
        client: _client.text.trim(),
        date: formatDateCourt(_date),
        lignes: valides,
        note: _note.text.trim(),
        adresseLivraison: _adresseLivraison.text.trim(),
        delaiPaiementJours: _delaiPaiement,
        echeance: _delaiPaiement > 0 && !_type.sansPrix
            ? formatDateCourt(_echeance())
            : '',
      ),
      tvaPct: store.profile.tva,
      motif: _motif.text.trim(),
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
                          libelle: t.libelle,
                          quantite: 1,
                          prixUnitaire: t.prix,
                          // L'unité de la fiche tarif est proposée, mais reste
                          // MODIFIABLE dans l'éditeur de ligne : deux
                          // lignes du même article peuvent avoir des
                          // unités différentes (10 kg + 3 colis).
                          unite: t.unite.trim().isEmpty ? 'pcs' : t.unite));
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
          onChanged: (v) => onChanged(ligne.copyWith(libelle: v)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              initialValue: ligne.reference,
              decoration: const InputDecoration(labelText: 'Réf.'),
              onChanged: (v) => onChanged(ligne.copyWith(reference: v)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              initialValue: ligne.quantite == 0 ? '' : '${ligne.quantite}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qté'),
              validator: (v) => V.entier(v, min: 1, label: 'Qté'),
              onChanged: (v) =>
                  onChanged(ligne.copyWith(quantite: int.tryParse(v) ?? 0)),
            ),
          ),
          const SizedBox(width: 10),
          // Unité de vente : sans elle « 3 » ne dit rien (3 pièces ? 3 kg ?
          // 3 heures ?). Champ étroit + liste de suggestions, parce que
          // les unités réelles sont peu nombreuses et connues.
          Expanded(
            child: TextFormField(
              initialValue: ligne.unite,
              decoration: const InputDecoration(labelText: 'Unité'),
              onChanged: (v) => onChanged(ligne.copyWith(
                  unite: v.trim().isEmpty ? 'pcs' : v.trim())),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (!sansPrix)
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: ligne.prixUnitaire == 0
                    ? ''
                    : ligne.prixUnitaire.toStringAsFixed(0),
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: 'Prix unit. ($devise)'),
                onChanged: (v) => onChanged(ligne.copyWith(
                    prixUnitaire:
                        double.tryParse(v.replaceAll(' ', '')) ?? 0)),
              ),
            ),
          if (!sansPrix) const SizedBox(width: 10),
          if (onSupprimer != null)
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: onSupprimer),
        ]),
      ]),
    );
  }
}
