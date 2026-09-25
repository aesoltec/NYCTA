import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../data/store.dart';
import '../../models/document.dart';
import '../../services/document_service.dart';
import '../../services/media_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/app_image.dart';
import '../../widgets/signature_pad.dart';

/// Aperçu d'un document. Deux modes :
/// - construction : [type] + [client] + [lignes] → numéro généré, puis sauvegardé
/// - pré-construit : [docExistant] (historique / transformation devis→facture)
class DocumentPreviewScreen extends StatefulWidget {
  final TypeDocument? type;
  final String client;
  final List<LigneDoc> lignes;
  final DocumentBati? docExistant;
  // Date d'émission choisie dans le formulaire (mode construction).
  final DateTime? date;
  const DocumentPreviewScreen({
    super.key,
    this.type,
    this.client = '',
    this.lignes = const [],
    this.docExistant,
    this.date,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  DocumentBati? _doc;
  List<String> _stockIgnores = const [];

  @override
  void initState() {
    super.initState();
    if (widget.docExistant != null) {
      _doc = widget.docExistant;
    } else {
      _creerDocument();
    }
  }

  // Numéro attribué via une RPC réseau (atomique côté serveur en
  // production) : la construction ne peut donc plus être synchrone comme
  // avant — un court chargement s'affiche pendant l'attribution du numéro.
  Future<void> _creerDocument() async {
    final store = context.read<Store>();
    final doc = await DocumentService().build(
      profile: store.profile,
      numeroGenerator: store.numeroDocument,
      type: widget.type!,
      client: widget.client.isEmpty
          ? (widget.type == TypeDocument.bonCommande ? 'Fournisseur' : 'Client comptant')
          : widget.client,
      lignes: widget.lignes,
      date: widget.date,
    );
    // Historique P9 : chaque document consulté est enregistré.
    await store.enregistrerDocument(doc, date: widget.date);
    // Facture, ticket et bordereau de livraison : sortie de stock
    // automatique pour les lignes correspondant à un produit en stock.
    List<String> ignores = const [];
    if (doc.type.decrementeStock) {
      ignores = await store.deduireStockPourLignes(widget.lignes);
    }
    if (mounted) {
      setState(() {
        _doc = doc;
        _stockIgnores = ignores;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final doc = _doc;
    if (doc == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(doc.type.titre)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(children: [
              if (MediaService.existe(store.profile.logoPath))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppImage(store.profile.logoPath,
                      size: 64, borderRadius: BorderRadius.circular(12)),
                ),
              for (final (i, l) in DocumentService.entete(store.profile).indexed)
                Text(l,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: i == 0
                        ? Theme.of(context).textTheme.titleLarge
                        : TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const Divider(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Text(doc.numero,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                Text(doc.date, style: TextStyle(color: Colors.grey.shade600)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          _Bloc(titre: doc.type == TypeDocument.bonCommande ? 'Fournisseur' : 'Client',
              contenu: doc.client),
          if (_stockIgnores.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                  '⚠️ Stock insuffisant — non décrémenté : ${_stockIgnores.join(', ')}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10, offset: Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (doc.type.sansPrix)
                const Row(children: [
                  Expanded(flex: 5, child: _EnteteColonne('Article')),
                  Expanded(flex: 2, child: _EnteteColonne('Qté', droite: true)),
                ])
              else
                const Row(children: [
                  Expanded(flex: 5, child: _EnteteColonne('Article')),
                  Expanded(flex: 2, child: _EnteteColonne('Qté', droite: true)),
                  Expanded(flex: 3, child: _EnteteColonne('P.U.', droite: true)),
                  Expanded(flex: 3, child: _EnteteColonne('Total', droite: true)),
                ]),
              const Divider(height: 20),
              for (final l in doc.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Expanded(flex: 5,
                        child: Text(l.libelle,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13))),
                    Expanded(flex: 2,
                        child: Text('${l.quantite}',
                            textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                    if (!doc.type.sansPrix) ...[
                      Expanded(flex: 3,
                          child: Text(C.money(l.prixUnitaire, doc.devise),
                              textAlign: TextAlign.right,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 3,
                          child: Text(C.money(l.total, doc.devise),
                              textAlign: TextAlign.right,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ]),
                ),
              // Bordereau : aucun prix ni total (norme internationale) —
              // signatures livreur + réceptionnaire à la place.
              if (doc.type.sansPrix) ...[
                const Divider(height: 24),
                const Row(children: [
                  Expanded(child: _EnteteColonne('Livreur')),
                  Expanded(child: _EnteteColonne('Réceptionnaire (client)')),
                ]),
                const SizedBox(height: 8),
                const Row(children: [
                  Expanded(child: Text('Nom + signature + date',
                      style: TextStyle(fontSize: 12, color: Colors.grey))),
                  Expanded(child: Text('Nom + signature + date',
                      style: TextStyle(fontSize: 12, color: Colors.grey))),
                ]),
              ] else ...[
                const Divider(height: 24),
                _LigneTotal(label: 'Total HT', valeur: doc.totalHT, devise: doc.devise),
                _LigneTotal(label: 'TVA (${store.profile.tva} %)', valeur: doc.tva, devise: doc.devise),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Expanded(
                        child: Text('TOTAL À PAYER',
                            style: TextStyle(fontWeight: FontWeight.w800))),
                    Flexible(
                      child: Text(C.money(doc.totalTTC, doc.devise),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          if (MediaService.existe(store.profile.signaturePath) ||
              MediaService.existe(store.profile.cachetPath))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (MediaService.existe(store.profile.signaturePath))
                    Column(children: [
                      AppImage(store.profile.signaturePath,
                          width: 120, height: 60, size: 60),
                      const SizedBox(height: 4),
                      Text('Signature',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                  if (MediaService.existe(store.profile.cachetPath))
                    Column(children: [
                      AppImage(store.profile.cachetPath,
                          width: 90, height: 90, size: 90,
                          borderRadius: BorderRadius.circular(45)),
                      const SizedBox(height: 4),
                      Text('Cachet',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ]),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Signature manuscrite du client (tous types : facture, devis,
          // ticket, bon de commande, BL = réceptionnaire).
          _SignatureClient(doc: doc),
          const SizedBox(height: 12),
          if (store.profile.messagePied.isNotEmpty || store.profile.banque.isNotEmpty)
            _Bloc(
              titre: 'Informations',
              contenu: [
                if (store.profile.banque.isNotEmpty)
                  'Banque : ${store.profile.banque} — ${store.profile.coordonneesBancaires}',
                store.profile.messagePied,
              ].join('\n'),
            ),
          const SizedBox(height: 24),
          // ---------- P9 : Devis → Facture ----------
          if (doc.type == TypeDocument.devisProforma)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.transform_rounded),
                label: const Text('Transformer en FACTURE'),
                onPressed: () async {
                  final facture = await store.transformerDevisEnFacture(doc);
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(docExistant: facture),
                  ));
                },
              ),
            ),
          if (doc.type == TypeDocument.devisProforma) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter / partager en PDF'),
              onPressed: () async => PdfService.partager(doc, store.profile),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimer'),
              onPressed: () async => PdfService.imprimer(doc, store.profile),
            ),
          ),
        ],
      ),
    );
  }
}

/// Signature manuscrite du client : capture à l'émission (doigt/stylet),
/// persistée en local + rattachée cloud, réutilisée dans le PDF.
class _SignatureClient extends StatelessWidget {
  final DocumentBati doc;
  const _SignatureClient({required this.doc});

  @override
  Widget build(BuildContext context) {
    final store = context.read<Store>();
    final libelle = doc.type == TypeDocument.bonLivraison
        ? 'Réceptionnaire'
        : 'Signature du client';
    final existe = MediaService.existe(doc.signatureClientPath);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000),
              blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Column(children: [
        if (existe)
          AppImage(doc.signatureClientPath,
              width: 160, height: 80, size: 80),
        if (existe) const SizedBox(height: 4),
        Text(existe ? libelle : 'Aucune signature — $libelle',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.draw_outlined, size: 18),
            label: Text(existe ? 'Refaire signer' : 'Faire signer'),
            onPressed: () => SignaturePad.ouvrir(context, (bytes) async {
              if (bytes == null || bytes.isEmpty) return;
              final chemin = await MediaService.savePng(bytes,
                  'sig_${doc.numero.replaceAll('/', '-')}');
              await store.joindreSignatureClient(doc.numero, chemin);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Signature enregistrée')));
                // Recharge l'aperçu avec la signature.
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                    builder: (_) => DocumentPreviewScreen(
                        docExistant: doc.copyWith(
                            signatureClientPath: chemin))));
              }
            }),
          ),
        ),
      ]),
    );
  }
}

class _Bloc extends StatelessWidget {
  final String titre, contenu;
  const _Bloc({required this.titre, required this.contenu});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titre,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(contenu, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _EnteteColonne extends StatelessWidget {
  final String texte;
  final bool droite;
  const _EnteteColonne(this.texte, {this.droite = false});
  @override
  Widget build(BuildContext context) => Text(texte,
      textAlign: droite ? TextAlign.right : TextAlign.left,
      style: TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w800,
          color: Colors.grey.shade600));
}

class _LigneTotal extends StatelessWidget {
  final String label;
  final double valeur;
  final String devise;
  const _LigneTotal({required this.label, required this.valeur, required this.devise});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          Flexible(
            child: Text(C.money(valeur, devise),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}
