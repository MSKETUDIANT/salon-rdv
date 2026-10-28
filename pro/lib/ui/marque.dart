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
