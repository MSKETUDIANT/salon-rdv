import 'package:flutter/material.dart';

import '../../data/roles.dart';
import '../../data/planning.dart';
import '../../data/salon.dart';
import '../gerant/ecran_equipe.dart';
import '../gerant/ecran_prestations.dart';
import '../historique/ecran_historique.dart';
import '../planning/ecran_mon_planning.dart';
import '../planning/ecran_planning_equipe.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/marque.dart';

// Accueil d'un espace. Gérant : planning de l'équipe (#10), historique (#11)
// et configuration du salon (#9). Coiffeur : son planning (#10).
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
    final libelleBascule = autre == null
        ? null
        : "Passer à l'${autre.titre.toLowerCase()}";
    // Bascule et déconnexion dans la barre du haut (menu du compte), et la
    // bascule aussi sous le titre : visibles sans défiler, même avec les
    // quatre cartes du gérant sur un petit écran (#41).
    return PageCharte(
      actions: [
        MenuCompte(
          compte: compte,
          surDeconnexion: surDeconnexion,
          libelleBascule: libelleBascule,
          surBascule: autre == null ? null : () => surBascule(autre),
        ),
      ],
      enfants: [
        Semantics(
          header: true,
          child: Text(espace.titre, style: textes.headlineMedium),
        ),
        if (autre != null)
          TextButton(
            onPressed: () => surBascule(autre),
            child: Text(libelleBascule!),
          ),
        const SizedBox(height: Espaces.s4),
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
            titre: 'Historique',
            description: 'Prestations réalisées, absents et encaissements',
            surAppui: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EcranHistorique(planning: planning),
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
      ],
    );
  }
}
