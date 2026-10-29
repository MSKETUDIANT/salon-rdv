import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import 'ecran_coiffeur.dart';

// Coiffeurs du salon (rôle coiffeur, attribué via #2) : chacun ouvre sa fiche
// horaires, absences et compétences.
class EcranEquipe extends StatelessWidget {
  const EcranEquipe({super.key, required this.salon});
  final DepotSalon salon;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe')),
      body: ListeCharte(
        enfants: [
          Chargement<List<Coiffeur>>(
            lire: salon.coiffeurs,
            afficher: (context, coiffeurs, _) {
              if (coiffeurs.isEmpty) {
                return Text(
                  'Aucun coiffeur dans ce salon. Le rôle de coiffeur s\'attribue à un compte existant.',
                  style: textes.bodyLarge,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in coiffeurs) ...[
                    _LigneCoiffeur(
                      nom: c.nom,
                      surAppui: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EcranCoiffeur(salon: salon, coiffeur: c),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Ligne d'un coiffeur (#92, même logique que le lot 2) : avatar rond, nom,
// chevron ; filet fin, sans carte. Ce que la fiche contient (identique pour
// tous) est lu par TalkBack, pas répété à l'écran.
class _LigneCoiffeur extends StatelessWidget {
  const _LigneCoiffeur({required this.nom, required this.surAppui});
  final String nom;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$nom, horaires, absences et compétences',
      onTap: surAppui,
      excludeSemantics: true,
      child: InkWell(
        onTap: surAppui,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: Espaces.s2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Couleurs.separateur)),
          ),
          child: Row(
            children: [
              Avatar(nom: nom, taille: 40),
              const SizedBox(width: Espaces.s3),
              Expanded(child: Text(nom, style: textes.titleSmall)),
              const Icon(Icons.chevron_right, color: Couleurs.texteSecondaire),
            ],
          ),
        ),
      ),
    );
  }
}
