import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/company_profile.dart';
import 'journal_activite_screen.dart';
import 'sauvegardes_screen.dart';
import '../../services/media_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/signature_pad.dart';

/// Configuration de l'entreprise : identité, fiscal, devise, image de marque
/// (logo, cachet, signature manuscrite), fonds de roulement et budgets.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final p = context.read<Store>().profile;
    _c = {
      for (final f in _champs)
        f.key: TextEditingController(text: f.valeurInitiale(p))
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  static final _champs = <_Champ>[
    _Champ('nomEntreprise', 'Nom de l\'entreprise', (p) => p.nomEntreprise,
        icone: Icons.business),
    _Champ('devise', 'Devise (ex : FCFA, GNF, XOF…)', (p) => p.devise,
        icone: Icons.currency_exchange),
    _Champ('telephone', 'Téléphone 1', (p) => p.telephone, icone: Icons.phone),
    _Champ('telephone2', 'Téléphone 2', (p) => p.telephone2,
        icone: Icons.phone_iphone),
    _Champ('email', 'Email', (p) => p.email, icone: Icons.email_outlined),
    _Champ('adresse', 'Adresse complète', (p) => p.adresse,
        icone: Icons.location_on_outlined),
    _Champ('rccm', 'RCCM', (p) => p.rccm, icone: Icons.badge_outlined),
    _Champ('ifu', 'IFU (Identifiant Fiscal Unique)', (p) => p.ifu,
        icone: Icons.fact_check_outlined),
    _Champ(
        'autreRefFiscale', 'Autre référence fiscale', (p) => p.autreRefFiscale),
    _Champ('banque', 'Banque', (p) => p.banque,
        icone: Icons.account_balance_outlined),
    _Champ('coordonneesBancaires', 'Coordonnées bancaires (RIB…)',
        (p) => p.coordonneesBancaires),
    _Champ('messagePied', 'Message de pied de document', (p) => p.messagePied,
        maxLignes: 2),
    _Champ('tva', 'TVA (%) — 0 si non applicable',
        (p) => p.tva == 0 ? '' : '${p.tva}'),
  ];

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final store = context.read<Store>();
    final p = store.profile;
    await store.updateProfile(p.copyWith(
      nomEntreprise: _c['nomEntreprise']!.text.trim(),
      devise: _c['devise']!.text.trim().isEmpty
          ? 'FCFA'
          : _c['devise']!.text.trim(),
      telephone: _c['telephone']!.text.trim(),
      telephone2: _c['telephone2']!.text.trim(),
      email: _c['email']!.text.trim(),
      adresse: _c['adresse']!.text.trim(),
      rccm: _c['rccm']!.text.trim(),
      ifu: _c['ifu']!.text.trim(),
      autreRefFiscale: _c['autreRefFiscale']!.text.trim(),
      banque: _c['banque']!.text.trim(),
      coordonneesBancaires: _c['coordonneesBancaires']!.text.trim(),
      messagePied: _c['messagePied']!.text.trim(),
      tva: (V.pourcent(_c['tva']!.text) == null)
          ? V.prixValue(_c['tva']!.text)
          : 0,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Configuration enregistrée')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final p = store.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _Section(titre: '🎨 Image de marque (logo, cachet, signature)'),
            _TuileImage(
              titre: 'Logo de l\'entreprise',
              path: p.logoPath,
              fallbackIcon: Icons.business_outlined,
              onPick: (src) async {
                final path = await MediaService.pickImage(camera: src);
                if (path != null) {
                  await store
                      .updateProfile(store.profile.copyWith(logoPath: path));
                }
              },
              onSigner: null,
              onEffacer: () => store
                  .updateProfile(store.profile.copyWith(effacerLogo: true)),
            ),
            _TuileImage(
              titre: 'Cachet / empreinte',
              path: p.cachetPath,
              fallbackIcon: Icons.approval_outlined,
              onPick: (src) async {
                final path = await MediaService.pickImage(camera: src);
                if (path != null) {
                  await store
                      .updateProfile(store.profile.copyWith(cachetPath: path));
                }
              },
              onSigner: null,
              onEffacer: () => store
                  .updateProfile(store.profile.copyWith(effacerCachet: true)),
            ),
            _TuileImage(
              titre: 'Signature numérique',
              path: p.signaturePath,
              fallbackIcon: Icons.gesture_outlined,
              onPick: (src) async {
                final path = await MediaService.pickImage(camera: src);
                if (path != null) {
                  await store.updateProfile(
                      store.profile.copyWith(signaturePath: path));
                }
              },
              onSigner: () async {
                await SignaturePad.ouvrir(context, (bytes) async {
                  if (bytes == null) return;
                  final path = await MediaService.savePng(bytes,
                      'signature_${DateTime.now().millisecondsSinceEpoch}');
                  await store.updateProfile(
                      store.profile.copyWith(signaturePath: path));
                });
              },
              onEffacer: () => store.updateProfile(
                  store.profile.copyWith(effacerSignature: true)),
            ),
            const SizedBox(height: 8),
            _Section(titre: '👤 Identité de l\'entreprise'),
            for (final f in _champs.take(2)) _buildChamp(f),
            _Section(titre: '📞 Contacts & coordonnées'),
            for (final f in _champs.skip(2).take(4)) _buildChamp(f),
            _Section(titre: '📋 Références commerciales & fiscales'),
            for (final f in _champs.skip(6).take(3)) _buildChamp(f),
            _Section(titre: '🏦 Banque & documents'),
            for (final f in _champs.skip(9).take(4)) _buildChamp(f),
            const SizedBox(height: 20),
            _Section(titre: '💰 Fonds de roulement par boutique'),
            for (final b in store.boutiques)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.storefront_outlined),
                title:
                    Text(b.nom, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(
                    '${store.profile.fondsRoulement[b.id] ?? 0} ${store.profile.devise}'),
                onTap: () async {
                  final ctrl = TextEditingController(
                      text: '${store.profile.fondsRoulement[b.id] ?? 0}');
                  final v = await showDialog<double>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      scrollable: true,
                      title: Text('Fonds — ${b.nom}'),
                      content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                              labelText: 'Montant (${store.profile.devise})')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Annuler')),
                        FilledButton(
                            onPressed: () => Navigator.pop(
                                ctx,
                                (V.entier(ctrl.text,
                                            min: 0, label: 'Montant') ==
                                        null)
                                    ? V.prixValue(ctrl.text)
                                    : null),
                            child: const Text('OK')),
                      ],
                    ),
                  );
                  if (v != null) await store.definirFondsRoulement(b.id, v);
                },
              ),
            const SizedBox(height: 12),
            _Section(titre: '🎯 Budgets mensuels par catégorie'),
            // store.catsCharge (dynamique) et non la constante categoriesCharge :
            // sinon une catégorie de charge ajoutée depuis l'écran Catégories
            // n'apparaissait jamais ici et son budget restait impossible à définir.
            for (final cat in store.catsCharge) _BudgetTile(categorie: cat),
            const SizedBox(height: 8),
            _Section(titre: '🔧 Système'),
            // Sauvegardes cloud de la base (v1.11).
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Sauvegardes de la base'),
              subtitle: const Text('Snapshot complet cloud + restauration'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SauvegardesScreen())),
            ),
            // Journal d'activité (v1.12) : qui a fait quoi, sur quelle table.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: const Text('Journal d\'activité'),
              subtitle: const Text('Qui a créé, modifié ou supprimé quoi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JournalActiviteScreen())),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_outlined),
                label: const Text('Enregistrer la configuration'),
                onPressed: _enregistrer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChamp(_Champ f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _c[f.key],
          maxLines: f.maxLignes,
          keyboardType: f.key == 'tva'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: f.label,
            prefixIcon: f.icone != null ? Icon(f.icone, size: 20) : null,
          ),
        ),
      );
}

class _Champ {
  final String key, label;
  final String Function(CompanyProfile) valeurInitiale;
  final IconData? icone;
  final int maxLignes;
  _Champ(this.key, this.label, this.valeurInitiale,
      {this.icone, this.maxLignes = 1});
}

class _Section extends StatelessWidget {
  final String titre;
  const _Section({required this.titre});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
        child: Text(titre, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Tuile image de marque : aperçu + actions (galerie / photo / signer / effacer).
class _TuileImage extends StatelessWidget {
  final String titre;
  final String? path;
  final IconData fallbackIcon;
  final Future<void> Function(bool camera)? onPick;
  final Future<void> Function()? onSigner;
  final Future<void> Function()? onEffacer;
  const _TuileImage({
    required this.titre,
    required this.path,
    required this.fallbackIcon,
    this.onPick,
    this.onSigner,
    this.onEffacer,
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
              color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Row(children: [
        AppImage(path, size: 56, fallbackIcon: fallbackIcon),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              path == null ? 'Non défini' : 'Défini ✓',
              style: TextStyle(
                  fontSize: 12,
                  color: path == null
                      ? Colors.grey.shade500
                      : const Color(0xFF3E9D8F)),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) async {
            if (v == 'galerie') await onPick?.call(false);
            if (v == 'photo') await onPick?.call(true);
            if (v == 'signer') await onSigner?.call();
            if (v == 'effacer') await onEffacer?.call();
          },
          itemBuilder: (_) => [
            if (onPick != null) ...[
              const PopupMenuItem(
                  value: 'galerie',
                  child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.photo_library_outlined),
                      title: Text('Importer (galerie)'))),
              const PopupMenuItem(
                  value: 'photo',
                  child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.photo_camera_outlined),
                      title: Text('Prendre une photo'))),
            ],
            if (onSigner != null)
              const PopupMenuItem(
                  value: 'signer',
                  child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.gesture_outlined),
                      title: Text('Signer à main levée'))),
            if (path != null)
              const PopupMenuItem(
                  value: 'effacer',
                  child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.delete_outline, color: Colors.redAccent),
                      title: Text('Effacer',
                          style: TextStyle(color: Colors.redAccent)))),
          ],
        ),
      ]),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final String categorie;
  const _BudgetTile({required this.categorie});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final budget = store.profile.budgetsMensuels[categorie] ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.savings_outlined, size: 20),
      title: Text(categorie, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(budget > 0
          ? '${budget.toStringAsFixed(0)} ${store.profile.devise}'
          : 'Non défini'),
      onTap: () async {
        final ctrl = TextEditingController(
            text: budget > 0 ? budget.toStringAsFixed(0) : '');
        final v = await showDialog<double>(
          context: context,
          builder: (ctx) => AlertDialog(
            scrollable: true,
            title: Text('Budget mensuel — $categorie'),
            content: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Montant (${store.profile.devise})')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(
                      ctx,
                      (V.entier(ctrl.text, min: 0, label: 'Montant') == null)
                          ? V.prixValue(ctrl.text)
                          : null),
                  child: const Text('OK')),
            ],
          ),
        );
        if (v != null) {
          await store.updateProfile(store.profile.copyWith(
            budgetsMensuels: {...store.profile.budgetsMensuels, categorie: v},
          ));
        }
      },
    );
  }
}
