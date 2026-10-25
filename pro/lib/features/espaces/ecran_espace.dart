import 'package:flutter/material.dart';

import '../../data/roles.dart';
import '../../data/planning.dart';
import '../../data/salon.dart';
import '../gerant/ecran_equipe.dart';
import '../gerant/ecran_prestations.dart';
import '../planning/ecran_mon_planning.dart';
import '../planning/ecran_planning_equipe.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Accueil d'un espace. Gérant : planning de l'équipe (#10) et configuration
// du salon (#9). Coiffeur : son planning (#10).
class EcranEspace extends StatelessWidget {
  const EcranEspace({
    super.key,
    required this.espace,
    required this.salon,
    required this.planning,
    required this.compte,
    required this.surBascule,
    required this.surDeconnexion,
    this.autreEspace,
  });

  final Espace espace;
  final DepotSalon salon;
  final DepotPlanning planning;
  final String compte;
  // Gérant qui est aussi coiffeur : bascule vers l'autre espace.
  final Espace? autreEspace;
  final ValueChanged<Espace> surBascule;
  final VoidCallback surDeconnexion;

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
            titre: "Planning de l'équipe",
            description: 'Tous les coiffeurs sur une journée',
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EcranPlanningEquipe(planning: planning),
              ),
            ),
          ),
          const SizedBox(height: Espaces.s3),
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
          CarteLien(
            titre: 'Mon planning',
            description: 'Rendez-vous du jour et de la semaine',
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EcranMonPlanning(planning: planning),
              ),
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
