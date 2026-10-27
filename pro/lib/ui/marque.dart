import 'package:flutter/material.dart';

import 'charte.dart';

// Logo du produit « Salon RDV » (#55, #41) : Newsreader 500, taille optique
// 36, couleur accent, comme web/components/marque/logo-salon-rdv.tsx (en
// tracés sur le site, ici avec la police embarquée). Lu « Salon RDV ».
class LogoSalonRdv extends StatelessWidget {
  const LogoSalonRdv({super.key, this.taille = Tailles.xl});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Salon RDV',
      excludeSemantics: true,
      child: Text(
        'Salon RDV',
        style: TextStyle(
          fontFamily: policeTitre,
          fontSize: taille,
          height: 1.2,
          fontWeight: FontWeight.w500,
          fontVariations: const [
            FontVariation.weight(500),
            FontVariation.opticalSize(36),
          ],
          color: Couleurs.accent,
        ),
      ),
    );
  }
}

enum _ActionCompte { bascule, deconnexion }

// Menu du compte, à droite de la barre du haut (#41) : compte connecté,
// bascule vers l'autre espace (gérant qui est aussi coiffeur) et
// déconnexion, sans défiler quel que soit le contenu de l'écran.
class MenuCompte extends StatelessWidget {
  const MenuCompte({
    super.key,
    required this.compte,
    required this.surDeconnexion,
    this.libelleBascule,
    this.surBascule,
  });

  final String compte;
  final VoidCallback surDeconnexion;
  // « Passer à l'espace coiffeur », si une bascule est possible.
  final String? libelleBascule;
  final VoidCallback? surBascule;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final bascule = libelleBascule;
    Widget entree(IconData icone, String libelle) => Row(
      children: [
        ExcludeSemantics(child: Icon(icone, color: Couleurs.texteSecondaire)),
        const SizedBox(width: Espaces.s3),
        Flexible(child: Text(libelle, style: textes.bodyLarge)),
      ],
    );
    return PopupMenuButton<_ActionCompte>(
      tooltip: 'Menu du compte',
      icon: const Icon(Icons.account_circle_outlined),
      position: PopupMenuPosition.under,
      color: Couleurs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon),
        side: const BorderSide(color: Couleurs.separateur),
      ),
      onSelected: (action) => switch (action) {
        _ActionCompte.bascule => surBascule?.call(),
        _ActionCompte.deconnexion => surDeconnexion(),
      },
      itemBuilder: (_) => [
        // Information, pas une action : couleurs explicites (une entrée
        // désactivée serait estompée sous le seuil de contraste).
        PopupMenuItem<_ActionCompte>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connecté avec', style: textes.bodySmall),
              Text(compte, style: textes.titleSmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        if (bascule != null)
          PopupMenuItem(
            value: _ActionCompte.bascule,
            child: entree(Icons.swap_horiz, bascule),
          ),
        PopupMenuItem(
          value: _ActionCompte.deconnexion,
          child: entree(Icons.logout, 'Se déconnecter'),
        ),
      ],
    );
  }
}
