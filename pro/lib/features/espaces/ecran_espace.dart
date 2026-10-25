import 'package:flutter/material.dart';

import '../../data/roles.dart';
import '../../data/salon.dart';
import '../gerant/ecran_equipe.dart';
import '../gerant/ecran_prestations.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Accueil d'un espace. Gérant : configuration du salon (#9). Coiffeur :
// planning, à venir avec #10.
class EcranEspace extends StatelessWidget {
  const EcranEspace({
    super.key,
    required this.espace,
    required this.salon,
    required this.compte,
    required this.surBascule,
    required this.surDeconnexion,
    this.autreEspace,
  });

  final Espace espace;
  final DepotSalon salon;
  final String compte;
  // Gérant qui est aussi coiffeur : bascule vers l'autre espace.
  final Espace? autreEspace;
  final ValueChanged<Espace> surBascule;
  final VoidCallback surDeconnexion;

  // Le contenu de l'espace coiffeur arrive avec #10.
  static const _aVenirCoiffeur =
      'Bientôt ici : votre planning du jour et de la semaine, '
      'et le détail de vos rendez-vous.';

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
        if (espace == Espace.gerant) ...[
          CarteLien(
            titre: 'Prestations',
            description: 'Catalogue : créer, modifier, désactiver',
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranPrestations(salon: salon)),
            ),
          ),
          const SizedBox(height: Espaces.s3),
          CarteLien(
            titre: 'Équipe',
            description: 'Horaires, absences et compétences de chaque coiffeur',
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => EcranEquipe(salon: salon)),
            ),
          ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Espaces.s4),
              child: Text(_aVenirCoiffeur, style: textes.bodyLarge),
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
