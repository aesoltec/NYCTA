import 'package:flutter/material.dart';

/// Géométrie des cartes de grille, pour une taille UNIFORME.
///
/// PROBLÈME
/// --------
/// Les cartes produit et article avaient un titre sur 1 ou 2 lignes, dans
/// une grille « masonry » qui empile les hauteurs. Résultat : des cartes
/// de tailles différentes dans la même rangée, une lecture irrégulière,
/// et une hauteur de ligne qui change au défilement.
///
/// DÉCISION
/// --------
/// 1. Le titre occupe **toujours deux lignes** (la seconde vide si le
///    libellé tient en une) : le bloc texte a donc une hauteur constante.
/// 2. La carte reçoit une hauteur **fixe** fournie par la grille
///    (`SliverGridDelegateWithFixedCrossAxisCount.mainAxisExtent`), pas
///    une hauteur déduite de `childAspectRatio` qui dépend de la
///    largeur — donc variable d'un téléphone à l'autre.
/// 3. Cette hauteur suit l'échelle de texte du système, sinon elle
///    déborde à 1.5x ou 2.0x. `mainAxisExtent` ne dépend pas de la
///    largeur : c'est la seule delegate qui donne une taille réellement
///    constante quelle que soit la largeur.
class CarteGrille {
  const CarteGrille._();

  /// Hauteur de la zone image. Constante : c'est elle qui donne au
  /// catalogue son air de galerie.
  static const imageHauteur = 150.0;

  /// Part non textuelle du bloc : marges internes, espacements, et
  /// chroma du bouton. Ces valeurs ne suivent PAS l'echelle de texte.
  ///
  /// Elle a ete calibree sur la hauteur reelle des deux cartes, une fois
  /// les libelles de boutons verrouilles sur une ligne (auparavant le
  /// libelle « Utiliser dans vente » passait a la ligne sur 148 px de
  /// large : la hauteur du bouton dependait alors de la largeur ET de
  /// l'echelle de texte, et aucune constante ne pouvait suivre).
  ///
  /// Sur-estimer est sans risque : le `Spacer` de la carte absorbe le
  /// surplus. Sous-estimer deborderait.
  /// Mesure : 68 px deborderait de 10 px sur l'ecran Stock a 320 px,
  /// 86 px laissait un vide visible. 82 px est le point calibre.
  static const chrome = 82.0;

  /// Hauteur des lignes de texte à l'échelle 1.0 (carte PRODUIT :
  /// titre, catégorie, prix, prix d'achat, stock).
  static const texte = 105.0;

  /// Idem pour une carte ARTICLE : pas de prix d'achat ni de stock.
  /// Contenu reel = titre (2 x 17.5) + categorie (~15) + prix (~22).
  /// Marge de securite : le `Spacer` absorbe le surplus, mais un
  /// deficit deborderait.
  static const texteArticle = 80.0;

  /// Hauteur totale d'une carte pour l'échelle de texte courante.
  static double hauteur(BuildContext context, {double texte = texte}) =>
      hauteurPour(MediaQuery.textScalerOf(context).scale(1.0),
          texte: texte);

  /// Même calcul, à partir de l'échelle seule — donc utilisable sans
  /// `BuildContext` (tests, delegates construites en amont du `build`).
  static double hauteurPour(double echelle, {double texte = texte}) =>
      imageHauteur + chrome + texte * echelle;
}

/// Place le corps texte d'une carte dans la hauteur restante.
///
/// Une carte de grille reçoit une hauteur FIXE : le corps occupe donc
/// toute la place au-dessus du bouton, qui se retrouve collé en bas.
///
/// Hors grille (liste, défilement, apercu), la hauteur n'est pas bornée :
/// `Expanded` y provoquerait une erreur de layout. Le corps se réduit
/// alors a son contenu. Les deux cas sont prevus plutot que d'imposer
/// au appelant de toujours passer par une grille.
class SlotCorps extends StatelessWidget {
  final Widget child;

  const SlotCorps({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, contraintes) {
      final borne = contraintes.hasBoundedHeight;
      return borne ? Expanded(child: child) : child;
    });
  }
}

/// Espace de rappel d'un `Spacer`, mais qui disparait si la hauteur
/// n'est pas bornee.
///
/// Meme raison que [SlotCorps] : en liste ou dans un defilement, un
/// `Spacer` (donc un `Expanded`) ferait echouer la mise en page. La carte
/// se resserre alors sur son contenu au lieu de planter.
class EspaceCarte extends StatelessWidget {
  const EspaceCarte({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, contraintes) => contraintes
            .hasBoundedHeight
        ? const Spacer()
        : const SizedBox.shrink());
  }
}

/// Bloc de titre à hauteur constante : deux lignes réservées, la
/// seconde restante vide si le libellé tient en une.
///
/// C'est ce qui rend les cartes uniformes : sans cela, un libellé court
/// produit une carte plus basse, et la grille devient irrégulière.
class TitreCarte extends StatelessWidget {
  final String texte;
  final double echelle;

  const TitreCarte({super.key, required this.texte, this.echelle = 1.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2 * 17.5 * echelle,
      child: Text(
        texte,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
