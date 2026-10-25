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
                    CarteLien(
                      titre: c.nom,
                      description: 'Horaires, absences et compétences',
                      surAppui: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EcranCoiffeur(salon: salon, coiffeur: c),
                        ),
                      ),
                    ),
                    const SizedBox(height: Espaces.s3),
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
