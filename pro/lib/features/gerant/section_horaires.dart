import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import 'ecran_semaine.dart';

// Horaires hebdomadaires d'un coiffeur (BF-G1), fiche coiffeur du gérant :
// résumé des 7 jours. Toute modification se fait sur l'écran « Horaires de
// la semaine » (#151, option B) : bouton « Modifier les horaires », ou un
// jour touché.

class SectionHoraires extends StatefulWidget {
  const SectionHoraires({
    super.key,
    required this.salon,
    required this.coiffeur,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  State<SectionHoraires> createState() => _SectionHorairesState();
}

class _SectionHorairesState extends State<SectionHoraires> {
  int _version = 0;
  // Plages lues, point de départ de l'écran de la semaine.
  List<Plage> _plages = const [];

  Future<void> _modifier() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EcranSemaine(
          salon: widget.salon,
          coiffeur: widget.coiffeur,
          plages: _plages,
        ),
      ),
    );
    if (!mounted || message == null) return;
    confirmer(context, message);
    setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Chargement<List<Plage>>(
          key: ValueKey(_version),
          lire: () async =>
              _plages = await widget.salon.plages(widget.coiffeur.id),
          // Sans carte (#96) : un jour par ligne, filets fins.
          afficher: (context, plages, _) => Column(
            children: [
              for (var jour = 1; jour <= 7; jour++) ...[
                _LigneJour(
                  jour: jour,
                  plages: plages.where((p) => p.jour == jour).toList()
                    ..sort(
                      (a, b) => minutesDuJour(a.debut) - minutesDuJour(b.debut),
                    ),
                  surAppui: _modifier,
                ),
                const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: Espaces.s3),
        // Comme « Ajouter une prestation » : bouton vert à sa largeur.
        Align(
          alignment: Alignment.centerLeft,
          child: Bouton(libelle: 'Modifier les horaires', surAppui: _modifier),
        ),
      ],
    );
  }
}

// Un jour du résumé : nom, puis une plage par ligne (jamais coupée en fin de
// ligne) ou « Ne travaille pas ». Toute la ligne ouvre l'écran de la semaine.
class _LigneJour extends StatelessWidget {
  const _LigneJour({
    required this.jour,
    required this.plages,
    required this.surAppui,
  });
  final int jour;
  final List<Plage> plages;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final nom = nomsJours[jour - 1];
    final heures = [
      for (final p in plages) '${formatHeure(p.debut)} – ${formatHeure(p.fin)}',
    ];
    return Semantics(
      button: true,
      label: heures.isEmpty
          ? '$nom, ne travaille pas, modifier les horaires'
          : '$nom, ${heures.join(' et ')}, modifier les horaires',
      onTap: surAppui,
      excludeSemantics: true,
      child: InkWell(
        onTap: surAppui,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, child: Text(nom, style: textes.titleSmall)),
              Expanded(
                child: heures.isEmpty
                    ? Text('Ne travaille pas', style: textes.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final h in heures)
                            Text(
                              h,
                              style: textes.bodyLarge!.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              const Icon(Icons.chevron_right, color: Couleurs.texteSecondaire),
            ],
          ),
        ),
      ),
    );
  }
}
