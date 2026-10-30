import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../ui/charte.dart';

// Apparence des états d'un rendez-vous (#64) : couleurs, icône, libellé.

// Apparence d'un état (#64, charte : CouleursStatut). Le libellé est
// toujours écrit, doublé d'une icône : jamais la couleur seule.
class StyleEtat {
  const StyleEtat({
    required this.fond,
    required this.bordure,
    required this.texte,
    required this.libelle,
    required this.icone,
  });
  final Color fond;
  final Color bordure;
  final Color texte;
  // Couleur du libellé de l'état (« En cours », « Absent »).
  final Color libelle;
  final IconData icone;

  factory StyleEtat.de(EtatRendezVous etat) => switch (etat) {
    EtatRendezVous.aVenir => const StyleEtat(
      fond: Couleurs.surface,
      bordure: Couleurs.accent,
      texte: Couleurs.texte,
      libelle: Couleurs.accent,
      icone: Icons.radio_button_unchecked,
    ),
    EtatRendezVous.enCours => const StyleEtat(
      fond: Couleurs.accent,
      bordure: Couleurs.accent,
      texte: Couleurs.surface,
      libelle: Couleurs.surface,
      icone: Icons.schedule,
    ),
    EtatRendezVous.aCloturer => const StyleEtat(
      fond: CouleursStatut.aCloturerFond,
      bordure: CouleursStatut.aCloturerBordure,
      texte: Couleurs.texte,
      libelle: CouleursStatut.aCloturerTexte,
      icone: Icons.pending_outlined,
    ),
    EtatRendezVous.termine => const StyleEtat(
      fond: CouleursStatut.termineFond,
      bordure: CouleursStatut.termineFond,
      texte: Couleurs.texte,
      libelle: Couleurs.texteSecondaire,
      icone: Icons.check,
    ),
    EtatRendezVous.absent => const StyleEtat(
      fond: CouleursStatut.absentFond,
      bordure: CouleursStatut.absentFond,
      texte: Couleurs.texte,
      libelle: CouleursStatut.absentTexte,
      icone: Icons.close,
    ),
  };
}

// Libellé de l'état précédé de son icône (décorative).
class LibelleEtat extends StatelessWidget {
  const LibelleEtat({super.key, required this.etat});
  final EtatRendezVous etat;

  @override
  Widget build(BuildContext context) {
    final style = StyleEtat.de(etat);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(style.icone, size: 18, color: style.libelle),
        ),
        const SizedBox(width: Espaces.s1),
        Text(
          etat.libelle,
          style: Theme.of(
            context,
          ).textTheme.labelLarge!.copyWith(color: style.libelle),
        ),
      ],
    );
  }
}
