import 'package:flutter/material.dart';

import '../../data/roles.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Accueil d'un espace. Le contenu arrive avec les issues suivantes :
// planning du coiffeur (#10), configuration du salon (#9) et vue équipe (#10).
class EcranEspace extends StatelessWidget {
  const EcranEspace({
    super.key,
    required this.espace,
    required this.compte,
    required this.surBascule,
    required this.surDeconnexion,
    this.autreEspace,
  });

  final Espace espace;
  final String compte;
  // Gérant qui est aussi coiffeur : bascule vers l'autre espace.
  final Espace? autreEspace;
  final ValueChanged<Espace> surBascule;
  final VoidCallback surDeconnexion;

  static const _aVenir = {
    Espace.gerant:
        'Bientôt ici : horaires, absences, prestations et compétences, '
        'puis le planning de l\'équipe.',
    Espace.coiffeur:
        'Bientôt ici : votre planning du jour et de la semaine, '
        'et le détail de vos rendez-vous.',
  };

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final autre = autreEspace;
    return PageCharte(
      enfants: [
        Semantics(
          header: true,
          child: Text(espace.titre, style: textes.headlineMedium),
        ),
        const SizedBox(height: Espaces.s2),
        Text('Connecté avec $compte', style: textes.bodyLarge),
        const SizedBox(height: Espaces.s6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Espaces.s4),
            child: Text(_aVenir[espace]!, style: textes.bodyLarge),
          ),
        ),
        const SizedBox(height: Espaces.s6),
        if (autre != null) ...[
          Bouton(
            libelle: 'Passer à l\'${autre.titre.toLowerCase()}',
            secondaire: true,
            surAppui: () => surBascule(autre),
          ),
          const SizedBox(height: Espaces.s2),
        ],
        TextButton(
          onPressed: surDeconnexion,
          child: const Text('Se déconnecter'),
        ),
      ],
    );
  }
}
