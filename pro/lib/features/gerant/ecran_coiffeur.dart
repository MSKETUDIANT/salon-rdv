import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import 'section_absences.dart';
import 'section_competences.dart';
import 'section_horaires.dart';

export 'section_absences.dart';
export 'section_competences.dart';
export 'section_horaires.dart';

// Fiche d'un coiffeur pour le gérant : horaires hebdomadaires (plusieurs
// plages par jour), absences et compétences (BF-G1, BF-G3). Chaque
// changement modifie aussitôt les créneaux proposés aux clients.
class EcranCoiffeur extends StatelessWidget {
  const EcranCoiffeur({super.key, required this.salon, required this.coiffeur});
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(coiffeur.nom)),
      body: ListeCharte(
        enfants: [
          _Titre('Horaires'),
          SectionHoraires(salon: salon, coiffeur: coiffeur),
          const SizedBox(height: Espaces.s8),
          _Titre('Absences'),
          SectionAbsences(salon: salon, coiffeur: coiffeur),
          const SizedBox(height: Espaces.s8),
          _Titre('Compétences'),
          SectionCompetences(salon: salon, coiffeur: coiffeur),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.s3),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}
