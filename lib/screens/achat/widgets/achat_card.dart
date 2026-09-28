import 'package:flutter/material.dart';
import '../../../models/achat.dart';
import '../../../widgets/money_text.dart';
import 'ligne_achat_card.dart';

/// Carte commande : en-tête (numéro + statut), fournisseur + date,
/// totaux, lignes compactes (3 max + « voir plus »), actions.
class AchatCard extends StatelessWidget {
  final Achat achat;
  final VoidCallback? onVoir;
  final VoidCallback? onPayer;
  final VoidCallback? onAnnuler;
  final VoidCallback? onExporter;

  const AchatCard({
    super.key,
    required this.achat,
    this.onVoir,
    this.onPayer,
    this.onAnnuler,
    this.onExporter,
  });

  static const couleurs = {
    Achat.statutDemande: Color(0xFF7E57C2),
    Achat.statutEnAttente: Color(0xFFEF6C00),
    Achat.statutValide: Color(0xFF3D6FB4),
    Achat.statutRecu: Color(0xFF3E9D8F),
    Achat.statutAnnule: Color(0xFF9E9E9E),
  };

  static const libelles = {
    Achat.statutDemande: 'DEMANDE',
    Achat.statutEnAttente: 'EN ATTENTE',
    Achat.statutValide: 'VALIDÉ',
    Achat.statutRecu: 'REÇU',
    Achat.statutAnnule: 'ANNULÉ',
  };

  static String libelleStatut(String statut) =>
      libelles[statut] ?? statut.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final a = achat;
    final couleur = couleurs[a.statut] ?? Colors.grey;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onVoir,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(a.numero,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: couleur.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(libelleStatut(a.statut),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: couleur)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text('${a.fournisseurNom} · ${_date(a.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                for (final l in a.lignes.take(3))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2),
                    child: LigneAchatCard(ligne: l),
                  ),
                if (a.lignes.length > 3)
                  TextButton(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero),
                    onPressed: onVoir,
                    child: Text(
                        'Voir les ${a.lignes.length - 3} autre(s) ligne(s)…'),
                  ),
                const Divider(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          MoneyText(a.montantTTC,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          if (!a.estSolde &&
                              a.statut != Achat.statutAnnule)
                            Text(
                                'Dû : ${a.montantRestant.toStringAsFixed(0)} F',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD97706))),
                        ]),
                  ),
                  Flexible(
                    child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        children: [
                          if (onVoir != null)
                            TextButton(
                                onPressed: onVoir,
                                child: const Text('Détails')),
                          if (onPayer != null && a.peutPayer)
                            TextButton(
                                onPressed: onPayer,
                                child: const Text('Payer')),
                          if (onAnnuler != null &&
                              a.peutAnnuler)
                            TextButton(
                                onPressed: onAnnuler,
                                child: const Text('Annuler',
                                    style: TextStyle(
                                        color: Colors.redAccent))),
                          if (onExporter != null)
                            IconButton(
                              tooltip: 'Exporter PDF',
                              icon: const Icon(
                                  Icons.ios_share_outlined,
                                  size: 20),
                              onPressed: onExporter,
                            ),
                        ]),
                  ),
                ]),
              ]),
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
