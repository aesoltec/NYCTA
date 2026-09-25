import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/store.dart';
import '../../models/transaction.dart';
import '../../widgets/date_selector.dart';
import '../../widgets/money_text.dart';

/// Écran dédié au rôle « Partenaire hotspot » (P8) :
/// - Saisir une vente de forfait depuis SON téléphone
/// - Voir ses ventes du mois et le détail
/// - Voir sa part calculée (ventes × son taux)
///
/// Sécurité : côté serveur (RLS v1.1), un partenaire ne peut insérer QUE
/// des forfaits à SON nom, et ne lit QUE ses propres ventes.
class PartnerHomeScreen extends StatefulWidget {
  const PartnerHomeScreen({super.key});
  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montant = TextEditingController();
  final _client = TextEditingController();
  // Ancien C.dureesForfait.first codé en dur : impossible d'initialiser
  // ici (pas de context/store disponible à la construction du State) —
  // voir build(), où _duree est fixé une fois la liste dynamique connue.
  String? _duree;
  bool _busy = false;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    final dureesForfait = store.dureesForfaitListe;
    _duree ??= dureesForfait.isNotEmpty ? dureesForfait.first : null;
    final mois = store.moisCourant;
    final mesVentes = store.transactions
        .where((t) =>
            t.partenaireId != null &&
            t.type == TypeTransaction.forfaitHotspot &&
            C.moisKey(t.date) == mois)
        .toList();
    final total = mesVentes.fold(0.0, (s, t) => s + t.montant);
    // Production : son propre compte ; démo : premier partenaire.
    final moi = store.monPartenaireId != null
        ? store.partenaires.where((p) => p.id == store.monPartenaireId).firstOrNull
        : (store.partenaires.isNotEmpty ? store.partenaires.first : null);
    final taux = moi?.taux ?? 0.60;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ---- Ma part du mois ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3E9D8F),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${moi?.nom ?? 'Partenaire'} — mois $mois',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            MoneyText(total * taux,
                style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            Text('Ventes : ${C.money(total)} × ${(taux * 100).round()} %',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 20),
        Text('Vendre un forfait', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(children: [
              DropdownButtonFormField<String>(
                initialValue: _duree,
                decoration: const InputDecoration(labelText: 'Durée du forfait'),
                items: [for (final d in dureesForfait)
                    DropdownMenuItem(value: d, child: Text(d))],
                onChanged: (v) => setState(() => _duree = v),
                validator: (v) => v == null ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _montant,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Montant (${store.profile.devise})',
                    prefixIcon: const Icon(Icons.payments_outlined)),
                validator: (v) => V.prix(v),
              ),
              const SizedBox(height: 12),
              ChampDate(
                valeur: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _client,
                decoration: const InputDecoration(
                    labelText: 'Client (optionnel)',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _busy
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.wifi_rounded),
                  label: Text(_busy ? 'Envoi…' : 'Valider la vente'),
                  onPressed: _busy ? null : () => _vendre(store),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Text('Mes ventes du mois', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (mesVentes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('Aucune vente ce mois-ci',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          for (final t in mesVentes)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Row(children: [
                const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF039BE5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${t.details['duree'] ?? 'Forfait'}${t.clientNom != null ? ' · ${t.clientNom}' : ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text('${t.date.day}/${t.date.month} ${t.date.hour}h${t.date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                const SizedBox(width: 10),
                MoneyText(t.montant, style: const TextStyle(fontSize: 14)),
              ]),
            ),
      ],
    );
  }

  Future<void> _vendre(Store store) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    // Partenaire lié au compte (démo : premier partenaire ; cloud : users.partenaire_id)
    final monId = store.monPartenaireId ??
        (store.partenaires.isNotEmpty ? store.partenaires.first.id : null);
    await store.ajouterTransaction(
      type: TypeTransaction.forfaitHotspot,
      montant: V.prixValue(_montant.text),
      clientNom: _client.text.trim().isEmpty ? null : _client.text.trim(),
      partenaireId: monId,
      date: _date,
      details: {'duree': _duree, 'source': 'appli_partenaire'},
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _montant.clear();
      _client.clear();
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('✅ Vente envoyée — visible par le siège')));
  }
}

/// Coquille du partenaire : un seul écran, rien d'autre (sécurité par
/// simplicité — il ne voit ni caisse, ni stock, ni dépenses).
class PartnerShell extends StatelessWidget {
  const PartnerShell({super.key});
  @override
  Widget build(BuildContext context) {
    final store = context.watch<Store>();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Espace partenaire'),
          Text(store.partenaires.isNotEmpty ? store.partenaires.first.nom : '',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      ),
      body: const PartnerHomeScreen(),
    );
  }
}
