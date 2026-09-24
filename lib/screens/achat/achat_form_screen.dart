import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/achat.dart';
import '../../models/enums.dart';
import '../../models/produit.dart';
import '../../widgets/date_picker_field.dart';
import '../../widgets/money_text.dart';

/// Création / correction d'un achat (demande si vendeur/caissier).
/// Lignes dynamiques : produit du stock (prix d'achat prérempli) ou
/// article libre, quantité, prix unitaire, TVA — totaux recalculés live.
class AchatFormScreen extends StatefulWidget {
  final Achat? existant; // correction de brouillon uniquement
  const AchatFormScreen({super.key, this.existant});

  @override
  State<AchatFormScreen> createState() => _AchatFormScreenState();
}

class _LigneEdit {
  String produitId;
  final TextEditingController libelle;
  final TextEditingController quantite;
  final TextEditingController prix;
  final TextEditingController tva;
  _LigneEdit({
    this.produitId = '',
    String libelle = '',
    String quantite = '1',
    String prix = '',
    String tva = '',
  })  : libelle = TextEditingController(text: libelle),
        quantite = TextEditingController(text: quantite),
        prix = TextEditingController(text: prix),
        tva = TextEditingController(text: tva);
  void dispose() {
    libelle.dispose();
    quantite.dispose();
    prix.dispose();
    tva.dispose();
  }
}

class _AchatFormScreenState extends State<AchatFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fournisseurLibre = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _fournisseurId;
  String _modePaiement = 'especes';
  DateTime _date = DateTime.now();
  final List<_LigneEdit> _lignes = [];
  bool _busy = false;

  static const _modes = [
    ('especes', 'Espèces'),
    ('mobile_money', 'Mobile Money'),
    ('credit', 'Crédit'),
    ('virement', 'Virement'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existant;
    if (e == null) {
      _lignes.add(_LigneEdit());
    } else {
      _fournisseurId = e.fournisseurId.isEmpty ? null : e.fournisseurId;
      _fournisseurLibre.text =
          e.fournisseurId.isEmpty ? e.fournisseurNom : '';
      _reference.text = e.referenceFacture ?? '';
      _notes.text = e.notes ?? '';
      _modePaiement = e.modePaiement;
      _date = e.date;
      for (final l in e.lignes) {
        _lignes.add(_LigneEdit(
          produitId: l.produitId,
          libelle: l.produitNom,
          quantite: l.quantite.toStringAsFixed(
              l.quantite.truncateToDouble() == l.quantite ? 0 : 2),
          prix: l.prixUnitaire.toStringAsFixed(0),
          tva: l.tauxTVA.toStringAsFixed(0),
        ));
      }
    }
  }

  @override
  void dispose() {
    _fournisseurLibre.dispose();
    _reference.dispose();
    _notes.dispose();
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  double get _totalTTC {
    var total = 0.0;
    for (final l in _lignes) {
      final q = double.tryParse(
              l.quantite.text.trim().replaceAll(',', '.')) ??
          0;
      final p = V.prixValue(l.prix.text.isEmpty ? '0' : l.prix.text);
      final t = double.tryParse(
              l.tva.text.trim().replaceAll(',', '.')) ??
          0;
      total += q * p * (1 + t / 100);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final estDemandeur = !store.peut(Permission.gererAchats);
    final produits = store.produitsBoutique;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existant == null
              ? (estDemandeur ? 'Demande d\'achat' : 'Nouvel achat')
              : 'Corriger l\'achat')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            if (estDemandeur)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                    'Votre demande sera validée par le gérant ou le comptable.',
                    style: TextStyle(
                        fontSize: 12.5, color: Color(0xFF7E57C2))),
              ),
            DropdownButtonFormField<String?>(
              value: _fournisseurId,
              decoration: const InputDecoration(
                  labelText: 'Fournisseur (référencé)',
                  prefixIcon: Icon(Icons.local_shipping_outlined)),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('— Saisie libre ci-dessous —')),
                for (final f in store.fournisseurs)
                  DropdownMenuItem(
                      value: f.id,
                      child: Text(f.nom,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _fournisseurId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fournisseurLibre,
              decoration: const InputDecoration(
                  labelText: 'Fournisseur (nom libre)',
                  prefixIcon: Icon(Icons.person_outline)),
              validator: (v) {
                if (_fournisseurId != null) return null;
                return V.texte(v, 2, 'Fournisseur');
              },
            ),
            const SizedBox(height: 12),
            DatePickerField(
              valeur: _date,
              label: 'Date d\'achat',
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _modePaiement,
              decoration: const InputDecoration(
                  labelText: 'Mode de paiement prévu',
                  prefixIcon: Icon(Icons.payments_outlined)),
              items: [
                for (final m in _modes)
                  DropdownMenuItem(value: m.$1, child: Text(m.$2)),
              ],
              onChanged: (v) => setState(() => _modePaiement = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reference,
              decoration: const InputDecoration(
                  labelText: 'Référence facture (optionnel)',
                  prefixIcon: Icon(Icons.receipt_outlined)),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Text('Lignes', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                onPressed: () =>
                    setState(() => _lignes.add(_LigneEdit())),
              ),
            ]),
            for (var i = 0; i < _lignes.length; i++)
              _EditeurLigne(
                key: ValueKey(i),
                ligne: _lignes[i],
                produits: produits,
                tvaDefaut: store.profile.tva,
                peutSupprimer: _lignes.length > 1,
                onSupprimer: () =>
                    setState(() => _lignes.removeAt(i)),
                onChanged: () => setState(() {}),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Expanded(
                    child: Text('TOTAL TTC estimé',
                        style: TextStyle(fontWeight: FontWeight.w800))),
                MoneyText(_totalTTC,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_busy
                    ? 'Enregistrement…'
                    : (estDemandeur
                        ? 'Envoyer la demande'
                        : 'Enregistrer l\'achat')),
                onPressed: _busy ? null : () => _valider(store),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _nomFournisseur {
    if (_fournisseurId != null) {
      final store = context.read<Store>();
      return store.fournisseurs
          .where((f) => f.id == _fournisseurId)
          .firstOrNull
          ?.nom ??
          _fournisseurLibre.text.trim();
    }
    return _fournisseurLibre.text.trim();
  }

  Future<void> _valider(Store store) async {
    if (!_formKey.currentState!.validate()) return;
    final lignes = <LigneAchat>[];
    for (final l in _lignes) {
      if (l.libelle.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⚠️ Chaque ligne doit avoir un libellé')));
        return;
      }
      final q = double.tryParse(
              l.quantite.text.trim().replaceAll(',', '.')) ??
          0;
      if (q <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('⚠️ Quantité invalide : ${l.libelle.text}')));
        return;
      }
      lignes.add(LigneAchat(
        produitId: l.produitId,
        produitNom: l.libelle.text.trim(),
        quantite: q,
        prixUnitaire: l.prix.text.trim().isEmpty
            ? 0
            : V.prixValue(l.prix.text),
        tauxTVA: l.tva.text.trim().isEmpty
            ? 0
            : (double.tryParse(l.tva.text.trim().replaceAll(',', '.')) ?? 0),
      ));
    }
    setState(() => _busy = true);
    final String? erreur;
    if (widget.existant == null) {
      erreur = await store.creerAchat(Achat(
        id: 'nouveau',
        numero: '',
        boutiqueId: store.boutiqueId,
        fournisseurId: _fournisseurId ?? '',
        fournisseurNom: _nomFournisseur,
        lignes: lignes,
        date: _date,
        modePaiement: _modePaiement,
        referenceFacture:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdBy: store.user.id,
        createdAt: DateTime.now(),
      ));
    } else {
      final e = widget.existant!;
      erreur = await store.majAchat(e.copyWith(
        fournisseurId: _fournisseurId ?? '',
        fournisseurNom: _nomFournisseur,
        lignes: lignes,
        date: _date,
        modePaiement: _modePaiement,
        referenceFacture:
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (erreur != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('⚠️ $erreur')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Achat enregistré')));
    Navigator.of(context).pop();
  }
}

class _EditeurLigne extends StatelessWidget {
  final _LigneEdit ligne;
  final List<Produit> produits;
  final double tvaDefaut;
  final bool peutSupprimer;
  final VoidCallback onSupprimer;
  final VoidCallback onChanged;
  const _EditeurLigne({
    super.key,
    required this.ligne,
    required this.produits,
    required this.tvaDefaut,
    required this.peutSupprimer,
    required this.onSupprimer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Column(children: [
        DropdownButtonFormField<String?>(
          value: ligne.produitId.isEmpty ? null : ligne.produitId,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Produit du stock (optionnel)'),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('— Article libre —')),
            for (final p in produits)
              DropdownMenuItem(
                  value: p.id,
                  child: Text(p.libelle,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            ligne.produitId = v ?? '';
            if (v != null) {
              final p = produits.firstWhere((e) => e.id == v);
              ligne.libelle.text = p.libelle;
              ligne.prix.text = p.prixAchat.toStringAsFixed(0);
              if (ligne.tva.text.isEmpty) {
                ligne.tva.text = tvaDefaut.toStringAsFixed(0);
              }
            }
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: ligne.libelle,
          decoration: const InputDecoration(labelText: 'Libellé'),
          validator: (v) => V.texte(v, 2, 'Libellé'),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: ligne.quantite,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Qté'),
              validator: (v) => V.prix(v, label: 'Qté'),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: ligne.prix,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Prix d'achat"),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                return V.prix(v, label: 'Prix');
              },
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: ligne.tva,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'TVA %'),
              onChanged: (_) => onChanged(),
            ),
          ),
          if (peutSupprimer)
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: onSupprimer),
        ]),
      ]),
    );
  }
}
