import 'package:flutter/material.dart';

import 'charte.dart';

// Photo du salon (#105) : l'image envoyée par le gérant (adresse publique de
// l'espace « salons »), sinon l'image par défaut de l'app. Pendant le
// chargement, un fond gris uni (pas d'autre photo affichée un instant) ; si
// l'adresse ne répond pas, l'image par défaut. Coins arrondis de la charte.
class PhotoSalon extends StatelessWidget {
  const PhotoSalon({super.key, required this.adresse, required this.hauteur});

  final String? adresse;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final defaut = Image.asset(
      'assets/images/salon-defaut.webp',
      height: hauteur,
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.2),
    );
    final url = adresse;
    return Semantics(
      container: true,
      image: true,
      label: 'Photo du salon',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(rayon),
          child: url == null
              ? defaut
              : Image.network(
                  url,
                  height: hauteur,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  frameBuilder: (context, image, frame, synchrone) =>
                      frame == null && !synchrone
                      ? Container(
                          height: hauteur,
                          width: double.infinity,
                          color: Couleurs.separateur,
                        )
                      : image,
                  errorBuilder: (context, erreur, pile) => defaut,
                ),
        ),
      ),
    );
  }
}
