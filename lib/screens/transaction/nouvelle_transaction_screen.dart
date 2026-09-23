import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/transaction.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/section_header.dart';

/// Formulaire dynamique selon le type d'activité.
/// Création (transaction == null) ou modification (transaction != null,
/// ouverte depuis le Journal → Modifier).
/// Règles anti-overflow : ListView + clavier, champs denses, validation.
class NouvelleTransactionScreen extends StatefulWidget {
  final TypeTransaction type;
  final Tx? transaction;
  const NouvelleTransactionScreen(
      {super.key, required this.type, this.transaction});

  @override
  State<NouvelleTransactionScreen> createState() => _State();
}

class _State extends State<NouvelleTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montant;
  late final TextEditingController _cout;
  late final TextEditingController _client;
  late final TextEditingController _description;
  final _details = <String, dynamic>{};
  String? _partenaireId;
  String? _operateur;
  String? _operation;
  String? _domaine;
  String? _duree;
  bool _busy = false;
  // Date de l'opération : aujourd'hui par défaut (création) ou date
  // d'origine (modification), modifiable dans les deux cas.
  late DateTime _date;

  TypeTransaction get type => widget.type;
  bool get estModification => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _montant = TextEditingController(
        text: tx == null ? '' : tx.montant.toStringAsFixed(0));
    _cout = TextEditingController(
        text: tx == null || tx.cout == 0 ? '' : tx.cout.toStringAsFixed(0));
    _client = TextEditingController(text: tx?.clientNom ?? '');
    _date = tx?.date ?? DateTime.now();
    _partenaireId = tx?.partenaireId;
    if (tx != null) {
      _details.addAll(Map<String, dynamic>.from(tx.details));
      _description = TextEditingController(
          text: (tx.details['description']?.toString() ?? ''));
      _operateur = tx.details['operateur']?.toString();
      _operation = tx.details['operation']?.toString();
      _domaine = tx.details['domaine']?.toString();
      _duree = tx.details['duree']?.toString();
    } else {
      _description = TextEditingController();
    }
  }

  @override
  void dispose() {
    _montant.dispose();
    _cout.dispose();
    _client.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = C.infosTypes[type]!;
    final store = context.read<Store>();

    return Scaffold(
      appBar: AppBar(
          title: Text(estModification ? 'Modifier — $label' : label)),
      // CTA toujours visible (jamais caché par le clavier ou le scroll).
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color),
              icon: _busy
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(estModification
                      ? Icons.save_outlined
                      : Icons.check_rounded),
              label: Text(_busy
                  ? 'Enregistrement…'
                  : (estModification
                      ? 'Enregistrer les modifications'
                      : 'Valider la vente')),
              onPressed: _busy ? null : () => _valider(store),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // En-tête visuel doux
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Flexible(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800)),
                    Text('Boutique : ${store.boutiqueCourante.nom}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color.withValues(alpha: 0.75),
                            fontSize: 12.5)),
                  ],
                )),
              ]),
            ),
            const SizedBox(height: 18),
            ChampDate(
              valeur: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 14),
            ..._champsSpecifiques(store),
            if (_champsSpecifiques(store).isNotEmpty) const SizedBox(height: 14),
            const SectionHeader(titre: 'Montant'),
            TextFormField(
              controller: _montant,
              autofocus: !estModification,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                  labelText: 'Montant (${store.profile.devise})',
                  prefixIcon: const Icon(Icons.payments_outlined)),
              validator: (v) => V.prix(v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cout,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Coût support (optionnel)',
                  helperText: 'Achat matériel, commission… — pour calculer la marge',
                  prefixIcon: Icon(Icons.shopping_bag_outlined)),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                return V.prix(v, label: 'Coût');
              },
            ),
            const SizedBox(height: 18),
            const SectionHeader(titre: 'Client'),
            TextFormField(
              controller: _client,
              decoration: const InputDecoration(
                  labelText: 'Client (optionnel)',
                  prefixIcon: Icon(Icons.person_outline)),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) =>
                  _busy ? null : _valider(store),
            ),
          ],
        ),
      ),
    );
  }

  /// Champs dynamiques par activité — c'est ICI qu'on ajoute une activité.
  List<Widget> _champsSpecifiques(Store store) {
    switch (type) {
      case TypeTransaction.mobileMoney:
        return [
          _dropdown('Opérateur', store.opsMobileMoney, _operateur,
              (v) => setState(() {
                    _operateur = v;
                    _details['operateur'] = v;
                  })),
          const SizedBox(height: 14),
          _dropdown("Type d'opération",
              const ['Dépôt', 'Retrait', 'Transfert'], _operation,
              (v) => setState(() {
                    _operation = v;
                    _details['operation'] = v;
                  })),
        ];
      case TypeTransaction.prestationService:
        return [
          _dropdown("Domaine d'intervention", store.domainesPresta,
              _domaine, (v) => setState(() {
                    _domaine = v;
                    _details['domaine'] = v;
                  })),
          const SizedBox(height: 14),
          TextFormField(
            controller: _description,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Description de la prestation'),
          ),
        ];
      case TypeTransaction.forfaitHotspot:
        return [
          _dropdown('Durée du forfait', store.dureesForfaitListe, _duree,
              (v) => setState(() {
                    _duree = v;
                    _details['duree'] = v;
                  })),
          const SizedBox(height: 14),
          _dropdownPartenaire(store),
        ];
      case TypeTransaction.creditCommunication:
        // Liste distincte de Mobile Money (store.opsMobileMoney) — avant
        // v1.7, les deux formulaires partageaient C.operateurs par erreur.
        return [
          _dropdown('Opérateur', store.opsCredit, _operateur,
              (v) => setState(() {
                    _operateur = v;
                    _details['operateur'] = v;
                  })),
        ];
      case TypeTransaction.venteMateriel:
        if (estModification) {
          final lignes =
              (widget.transaction!.details['lignes'] as List?) ?? const [];
          final resume = lignes
              .map((l) => l is Map
                  ? '${l['quantite'] ?? 1}× ${l['libelle'] ?? ''}'
                  : '')
              .join(', ');
          return [
            _InfoBox(message:
                '🛒 Vente matériel : $resume\nLes quantités et le stock se gèrent depuis l\'onglet Stock — ici vous pouvez corriger montant, coût, client et date.'),
          ];
        }
        return [
          const _InfoBox(message:
              "🛒 La vente de matériel se fait depuis l'onglet Stock : "
              'choisissez le produit puis « Vendre » — la sortie de stock '
              'et la transaction sont créées ensemble.'),
        ];
    }
  }

  Widget _dropdown(String label, List<String> items, String? valeur,
      ValueChanged<String> on) {
    final initiale =
        (valeur != null && items.contains(valeur)) ? valeur : null;
    return DropdownButtonFormField<String>(
      initialValue: initiale,
      decoration: InputDecoration(labelText: label),
      items: [for (final v in items) DropdownMenuItem(value: v, child: Text(v))],
      onChanged: (v) => v != null ? on(v) : null,
      validator: (v) => v == null ? 'Requis' : null,
    );
  }

  Widget _dropdownPartenaire(Store store) {
    final pts = store.partenaires.where((p) => p.actif).toList();
    final initiale = (_partenaireId != null &&
            pts.any((p) => p.id == _partenaireId))
        ? _partenaireId
        : null;
    return DropdownButtonFormField<String>(
      initialValue: initiale,
      decoration: const InputDecoration(
          labelText: 'Vendu via partenaire (optionnel)',
          helperText: 'Laisser vide si vendu au siège'),
      items: [
        const DropdownMenuItem(value: '', child: Text('— Siège —')),
        for (final p in pts)
          DropdownMenuItem(
              value: p.id,
              child: Text('${p.nom} (${(p.taux * 100).round()} %)')),
      ],
      onChanged: (v) => setState(() => _partenaireId = (v == '' ? null : v)),
    );
  }

  Future<void> _valider(Store store) async {
    if (!_formKey.currentState!.validate()) return;
    final montant = V.prixValue(_montant.text);
    final cout = _cout.text.trim().isEmpty
        ? 0.0
        : V.prixValue(_cout.text);
    if (cout > montant) {
      // INCOHÉRENCE MÉTIER : marge négative — confirmation obligatoire.
      final confirme = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD97706)),
          title: const Text('Marge négative ⚠️'),
          content: Text(
              'Le coût support (${cout.toStringAsFixed(0)}) dépasse le '
              'montant encaissé (${montant.toStringAsFixed(0)}).\n\n'
              'Perte : ${(cout - montant).toStringAsFixed(0)} '
              '${store.profile.devise}.\n\nContinuer quand même ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Corriger')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmer')),
          ],
        ),
      );
      if (confirme != true) return;
    }
    setState(() => _busy = true);
    try {
      if (estModification) {
        final origine = widget.transaction!;
        Tx maj = origine.copyWith(
          montant: montant,
          cout: cout,
          clientNom: _client.text.trim().isEmpty ? null : _client.text.trim(),
          details: {
            ..._details,
            if (_description.text.isNotEmpty)
              'description': _description.text
          },
          date: _date,
        );
        // Partenaire (forfait) : remise à null explicite si « Siège ».
        if (type == TypeTransaction.forfaitHotspot) {
          maj = _partenaireId == null ? maj.sansPartenaire() : maj.copyWith(partenaireId: _partenaireId);
        }
        final erreur = await store.majTransaction(maj);
        if (!mounted) return;
        if (erreur != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Vente modifiée')),
        );
        Navigator.of(context).pop();
      } else {
        await store.ajouterTransaction(
          type: type,
          montant: montant,
          cout: cout,
          clientNom: _client.text.trim().isEmpty ? null : _client.text.trim(),
          partenaireId: type == TypeTransaction.forfaitHotspot ? _partenaireId : null,
          date: _date,
          details: {..._details, if (_description.text.isNotEmpty) 'description': _description.text},
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Vente enregistrée')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  const _InfoBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(message, style: const TextStyle(fontSize: 13)),
      );
}
