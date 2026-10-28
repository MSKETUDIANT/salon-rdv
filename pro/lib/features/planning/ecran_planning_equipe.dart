import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import 'elements_planning.dart';

// Planning de toute l'équipe pour le gérant (BF-G5) : la frise d'un coiffeur
// sur la journée, choisi par des pastilles en haut (#64), navigation entre les
// jours. Depuis la fiche d'un rendez-vous : clôture pour un coiffeur et
// encaissement (#11).
class EcranPlanningEquipe extends StatefulWidget {
  const EcranPlanningEquipe({super.key, required this.planning});
  final DepotPlanning planning;

  @override
  State<EcranPlanningEquipe> createState() => _EcranPlanningEquipeState();
}

class _EcranPlanningEquipeState extends State<EcranPlanningEquipe> {
  DateTime? _maintenant;
  // Coiffeur affiché ; le premier de l'équipe par défaut.
  String? _coiffeur;
  DateTime? _aujourdhui;
  DateTime? _jour;
  int _version = 0;

  Future<(DateTime, List<Coiffeur>, DonneesPlanning)> _lire() async {
    _maintenant = await widget.planning.maintenantAuSalon();
    _aujourdhui ??= DateUtils.dateOnly(_maintenant!);
    final jour = _jour ??= _aujourdhui!;
    final resultats = await Future.wait<dynamic>([
      widget.planning.coiffeurs(),
      widget.planning.periode(jour, jour),
    ]);
    return (
      jour,
      resultats[0] as List<Coiffeur>,
      resultats[1] as DonneesPlanning,
    );
  }

  void _deplacer(int jours) => setState(() {
    _jour = _jour!.add(Duration(days: jours));
    _version++;
  });

  void _actualiser() => setState(() => _version++);

  static String _resume(int n) => n == 0
      ? 'Aucun rendez-vous ce jour-là'
      : n == 1
      ? '1 rendez-vous'
      : '$n rendez-vous';

  // Fiche d'un rendez-vous ; après une clôture ou un encaissement, message et
  // relecture.
  Future<void> _ouvrir(RendezVous r, String coiffeur) async {
    final message = await afficherRendezVous(
      context,
      r,
      planning: widget.planning,
      maintenant: _maintenant!,
      gerant: true,
      coiffeur: coiffeur,
    );
    if (message == null || !mounted) return;
    confirmer(context, message);
    _actualiser();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          IconButton(
            onPressed: _actualiser,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _actualiser(),
        child: ListView(
          // Mêmes marges que ListeCharte (ui/composants.dart).
          padding: const EdgeInsets.fromLTRB(
            Espaces.s4,
            Espaces.s4,
            Espaces.s4,
            Espaces.s8,
          ),
          children: [
            Chargement<(DateTime, List<Coiffeur>, DonneesPlanning)>(
              // _version change avec la date (_deplacer, aujourd'hui) ; pas le
              // choix du coiffeur, déjà chargé.
              key: ValueKey(_version),
              lire: _lire,
              afficher: (context, resultat, _) {
                final (jour, coiffeurs, donnees) = resultat;
                final choisi = coiffeurs.isEmpty
                    ? null
                    : coiffeurs.firstWhere(
                        (c) => c.id == _coiffeur,
                        orElse: () => coiffeurs.first,
                      );
                final ids = [if (choisi != null) choisi.id];
                final (debut, fin) = fenetreDuJour(donnees, ids, jour);
                final total = donnees.rendezVous
                    .where((r) => memeJour(r.debut, jour))
                    .length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationDates(
                      unite: 'jour',
                      libelle: formatDate(jour),
                      surPrecedent: () => _deplacer(-1),
                      surSuivant: () => _deplacer(1),
                      surAujourdhui: memeJour(jour, _aujourdhui!)
                          ? null
                          : () => setState(() {
                              _jour = _aujourdhui;
                              _version++;
                            }),
                    ),
                    const SizedBox(height: Espaces.s2),
                    Text(
                      coiffeurs.isEmpty
                          ? 'Aucun coiffeur dans ce salon.'
                          : '${coiffeurs.length} coiffeur${coiffeurs.length > 1 ? 's' : ''} · '
                                '${total == 0 ? 'aucun rendez-vous' : '$total rendez-vous'}',
                      style: textes.bodyLarge,
                    ),
                    if (choisi != null) ...[
                      const SizedBox(height: Espaces.s3),
                      // Un coiffeur à la fois : pastilles de choix, défilantes
                      // si l'équipe ne tient pas en largeur.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in coiffeurs) ...[
                              ChoiceChip(
                                label: Text(c.nom),
                                labelStyle: textes.labelLarge!.copyWith(
                                  color: c.id == choisi.id
                                      ? Couleurs.surface
                                      : Couleurs.texte,
                                ),
                                selected: c.id == choisi.id,
                                showCheckmark: false,
                                onSelected: (_) =>
                                    setState(() => _coiffeur = c.id),
                              ),
                              const SizedBox(width: Espaces.s2),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: Espaces.s3),
                      Text(
                        '${choisi.nom} : ${_resume(donnees.rendezVousDu(choisi.id, jour).length).toLowerCase()}',
                        style: textes.bodySmall,
                      ),
                      const SizedBox(height: Espaces.s2),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(rayon),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AxeHeures(debut: debut, fin: fin),
                            Expanded(
                              child: ColonneJour(
                                jour: jour,
                                debut: debut,
                                fin: fin,
                                plages: donnees.plagesDu(choisi.id, jour),
                                absences: donnees.absencesDu(choisi.id, jour),
                                rendezVous: donnees.rendezVousDu(
                                  choisi.id,
                                  jour,
                                ),
                                maintenant: _maintenant!,
                                surRendezVous: (r) => _ouvrir(r, choisi.nom),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: Espaces.s2),
                    Text(
                      'Zones grisées : hors des horaires du coiffeur.',
                      style: textes.bodySmall,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
