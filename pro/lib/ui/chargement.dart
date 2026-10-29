import 'package:flutter/material.dart';

import '../data/salon.dart';
import 'charte.dart';
import 'composants.dart';

// Lecture asynchrone avec ses trois états : chargement (silhouettes grises,
// #83), erreur (message clair, réseau compris, avec « Réessayer »), données.
class Chargement<T> extends StatefulWidget {
  const Chargement({
    super.key,
    required this.lire,
    required this.afficher,
    this.silhouette = const SilhouetteListe(),
  });

  final Future<T> Function() lire;
  // Forme affichée pendant la lecture (liste par défaut).
  final Widget silhouette;
  final Widget Function(BuildContext context, T donnees, VoidCallback relire)
  afficher;

  @override
  State<Chargement<T>> createState() => _ChargementState<T>();
}

class _ChargementState<T> extends State<Chargement<T>> {
  late Future<T> _lecture = widget.lire();

  // Corps en accolades : setState ne doit pas recevoir une fonction qui
  // renvoie la Future (Flutter refuserait, et l'écran resterait sur l'erreur).
  void _relire() {
    setState(() {
      _lecture = widget.lire();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _lecture,
      builder: (context, etat) {
        if (etat.connectionState != ConnectionState.done) {
          return widget.silhouette;
        }
        if (etat.hasError) {
          final message = etat.error is ErreurSalon
              ? (etat.error as ErreurSalon).message
              : messageErreurInattendue(etat.error!);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MessageErreur(message),
              const SizedBox(height: Espaces.s3),
              Bouton(libelle: 'Réessayer', secondaire: true, surAppui: _relire),
            ],
          );
        }
        return widget.afficher(context, etat.data as T, _relire);
      },
    );
  }
}

// Message d'erreur annoncé aux lecteurs d'écran.
class MessageErreur extends StatelessWidget {
  const MessageErreur(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(color: Couleurs.erreur),
      ),
    );
  }
}

// Message bref après une action réussie.
void confirmer(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// Silhouettes de chargement (#83, option 1A) : formes grises à la place de
// la roue, avec un léger battement d'opacité (aucun si le téléphone demande
// moins d'animations). Annoncées « Chargement » aux lecteurs d'écran.
class Silhouette extends StatefulWidget {
  const Silhouette({super.key, required this.child});
  final Widget child;

  @override
  State<Silhouette> createState() => _SilhouetteState();
}

class _SilhouetteState extends State<Silhouette>
    with SingleTickerProviderStateMixin {
  late final _battement = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _battement
        ..stop()
        ..value = 1;
    } else if (!_battement.isAnimating) {
      _battement.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _battement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement',
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(opacity: _battement, child: widget.child),
      ),
    );
  }
}

Widget _barre(double largeur, double hauteur) => Container(
  width: largeur,
  height: hauteur,
  decoration: BoxDecoration(
    color: Couleurs.separateur,
    borderRadius: BorderRadius.circular(rayon),
  ),
);

// Liste : quatre lignes du gabarit des listes de l'app (rond, deux barres).
class SilhouetteListe extends StatelessWidget {
  const SilhouetteListe({super.key});

  @override
  Widget build(BuildContext context) {
    return Silhouette(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaces.s4),
        child: Column(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Couleurs.separateur,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Espaces.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.7,
                            child: _barre(double.infinity, 14),
                          ),
                          const SizedBox(height: Espaces.s2),
                          FractionallySizedBox(
                            widthFactor: 0.45,
                            child: _barre(double.infinity, 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Vue horaire du planning : des blocs gris dans une grille.
class SilhouettePlanning extends StatelessWidget {
  const SilhouettePlanning({super.key});

  @override
  Widget build(BuildContext context) {
    return Silhouette(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espaces.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _barre(double.infinity, 40),
            const SizedBox(height: Espaces.s4),
            for (final hauteur in [56.0, 56.0, 88.0, 56.0]) ...[
              Row(
                children: [
                  _barre(40, 12),
                  const SizedBox(width: Espaces.s3),
                  Expanded(child: _barre(double.infinity, hauteur)),
                ],
              ),
              const SizedBox(height: Espaces.s2),
            ],
          ],
        ),
      ),
    );
  }
}
