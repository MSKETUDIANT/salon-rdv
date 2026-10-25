import 'package:flutter/material.dart';

import '../data/salon.dart';
import 'charte.dart';
import 'composants.dart';

// Lecture asynchrone avec ses trois états : chargement, erreur (avec
// « Réessayer »), données.
class Chargement<T> extends StatefulWidget {
  const Chargement({super.key, required this.lire, required this.afficher});

  final Future<T> Function() lire;
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
          return const Padding(
            padding: EdgeInsets.all(Espaces.s8),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (etat.hasError) {
          final message = etat.error is ErreurSalon
              ? (etat.error as ErreurSalon).message
              : messageErreurBase(null);
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
