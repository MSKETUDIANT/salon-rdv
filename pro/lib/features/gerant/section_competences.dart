import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';

// Compétences d'un coiffeur, fiche coiffeur du gérant.

class SectionCompetences extends StatefulWidget {
  const SectionCompetences({
    super.key,
    required this.salon,
    required this.coiffeur,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  State<SectionCompetences> createState() => _SectionCompetencesState();
}

class _SectionCompetencesState extends State<SectionCompetences> {
  // Cochées, mises à jour aussitôt (et remises en cas d'échec).
  Set<String>? _cochees;
  final _enCours = <String>{};

  Future<(List<Prestation>, Set<String>)> _lire() async {
    final resultats = await Future.wait([
      widget.salon.prestations(),
      widget.salon.competences(widget.coiffeur.id),
    ]);
    final prestations = resultats[0] as List<Prestation>;
    final cochees = resultats[1] as Set<String>;
    _cochees = {...cochees};
    return (prestations, cochees);
  }

  Future<void> _basculer(Prestation p, bool cocher) async {
    if (_enCours.contains(p.id)) return;
    setState(() {
      _enCours.add(p.id);
      cocher ? _cochees!.add(p.id) : _cochees!.remove(p.id);
    });
    try {
      if (cocher) {
        await widget.salon.ajouterCompetence(widget.coiffeur.id, p.id);
      } else {
        await widget.salon.retirerCompetence(widget.coiffeur.id, p.id);
      }
      if (mounted) {
        confirmer(
          context,
          cocher
              ? 'Compétence ajoutée : ${p.nom}.'
              : 'Compétence retirée : ${p.nom}.',
        );
      }
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() => cocher ? _cochees!.remove(p.id) : _cochees!.add(p.id));
      confirmer(context, erreur.message);
    } finally {
      if (mounted) setState(() => _enCours.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Chargement<(List<Prestation>, Set<String>)>(
      lire: _lire,
      afficher: (context, donnees, _) {
        final prestations = donnees.$1;
        if (prestations.isEmpty) {
          return Text(
            'Aucune prestation dans le catalogue.',
            style: textes.bodyLarge,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cochez les prestations que ${widget.coiffeur.nom} sait faire.',
              style: textes.bodySmall,
            ),
            const SizedBox(height: Espaces.s2),
            // Sans carte (#96) : une prestation par ligne, filet fin.
            Column(
              children: [
                for (final p in prestations) ...[
                  CheckboxListTile(
                    value: _cochees!.contains(p.id),
                    onChanged: (v) => _basculer(p, v ?? false),
                    title: Text(p.nom, style: textes.bodyLarge),
                    subtitle: p.active
                        ? null
                        : Text('Désactivée', style: textes.bodySmall),
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Couleurs.accent,
                    side: const BorderSide(color: Couleurs.bordure, width: 2),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}
