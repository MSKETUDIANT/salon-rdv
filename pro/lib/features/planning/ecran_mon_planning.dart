import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import 'elements_planning.dart';

// Planning du coiffeur connecté (BF-K1) : vue Jour (heures hors horaires
// grisées) et vue Semaine ; appui sur un rendez-vous pour le détail (BF-K2).
// Relu à l'ouverture, à chaque changement de date, en tirant la liste vers
// le bas ou avec le bouton « Actualiser ».
class EcranMonPlanning extends StatefulWidget {
  const EcranMonPlanning({super.key, required this.planning});
  final DepotPlanning planning;

  @override
  State<EcranMonPlanning> createState() => _EcranMonPlanningState();
}

enum _Vue { jour, semaine }

class _EcranMonPlanningState extends State<EcranMonPlanning> {
  _Vue _vue = _Vue.jour;
  DateTime? _aujourdhui;
  DateTime? _jour;
  int _version = 0;

  Future<(DateTime, DonneesPlanning)> _lire() async {
    _aujourdhui ??= DateUtils.dateOnly(
      await widget.planning.maintenantAuSalon(),
    );
    final jour = _jour ??= _aujourdhui!;
    final du = _vue == _Vue.jour ? jour : lundiDe(jour);
    final au = _vue == _Vue.jour ? jour : du.add(const Duration(days: 6));
    final donnees = await widget.planning.periode(
      du,
      au,
      coiffeurId: widget.planning.moi,
    );
    return (jour, donnees);
  }

  void _deplacer(int sens) => setState(() {
    _jour = _jour!.add(Duration(days: sens * (_vue == _Vue.jour ? 1 : 7)));
    _version++;
  });

  void _actualiser() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon planning'),
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
          padding: const EdgeInsets.fromLTRB(
            Espaces.s4,
            Espaces.s2,
            Espaces.s4,
            Espaces.s8,
          ),
          children: [
            SegmentedButton<_Vue>(
              segments: const [
                ButtonSegment(value: _Vue.jour, label: Text('Jour')),
                ButtonSegment(value: _Vue.semaine, label: Text('Semaine')),
              ],
              selected: {_vue},
              showSelectedIcon: false,
              onSelectionChanged: (choix) => setState(() {
                _vue = choix.first;
                _version++;
              }),
            ),
            const SizedBox(height: Espaces.s3),
            Chargement<(DateTime, DonneesPlanning)>(
              key: ValueKey('$_version-$_vue-$_jour'),
              lire: _lire,
              afficher: (context, resultat, _) {
                final (jour, donnees) = resultat;
                final moi = widget.planning.moi ?? '';
                final lundi = lundiDe(jour);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    NavigationDates(
                      unite: _vue == _Vue.jour ? 'jour' : 'semaine',
                      libelle: _vue == _Vue.jour
                          ? formatDate(jour)
                          : 'Semaine du ${formatDate(lundi).toLowerCase()}',
                      surPrecedent: () => _deplacer(-1),
                      surSuivant: () => _deplacer(1),
                      surAujourdhui:
                          (_vue == _Vue.jour
                              ? memeJour(jour, _aujourdhui!)
                              : memeJour(lundi, lundiDe(_aujourdhui!)))
                          ? null
                          : () => setState(() {
                              _jour = _aujourdhui;
                              _version++;
                            }),
                    ),
                    const SizedBox(height: Espaces.s3),
                    if (_vue == _Vue.jour)
                      _VueJour(jour: jour, donnees: donnees, coiffeur: moi)
                    else
                      _VueSemaine(
                        lundi: lundi,
                        donnees: donnees,
                        coiffeur: moi,
                        surJour: (j) => setState(() {
                          _vue = _Vue.jour;
                          _jour = j;
                          _version++;
                        }),
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

class _VueJour extends StatelessWidget {
  const _VueJour({
    required this.jour,
    required this.donnees,
    required this.coiffeur,
  });
  final DateTime jour;
  final DonneesPlanning donnees;
  final String coiffeur;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final rdv = donnees.rendezVousDu(coiffeur, jour);
    final plages = donnees.plagesDu(coiffeur, jour);
    final (debut, fin) = fenetreDuJour(donnees, [coiffeur], jour);
    final resume = rdv.isEmpty
        ? 'Aucun rendez-vous'
        : rdv.length == 1
        ? '1 rendez-vous'
        : '${rdv.length} rendez-vous';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plages.isEmpty ? '$resume · ne travaille pas ce jour-là' : resume,
          style: textes.bodyLarge,
        ),
        const SizedBox(height: Espaces.s3),
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
                  plages: plages,
                  absences: donnees.absencesDu(coiffeur, jour),
                  rendezVous: rdv,
                  surRendezVous: (r) => afficherRendezVous(context, r),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espaces.s2),
        Text('Zones grisées : hors de vos horaires.', style: textes.bodySmall),
      ],
    );
  }
}

class _VueSemaine extends StatelessWidget {
  const _VueSemaine({
    required this.lundi,
    required this.donnees,
    required this.coiffeur,
    required this.surJour,
  });
  final DateTime lundi;
  final DonneesPlanning donnees;
  final String coiffeur;
  final ValueChanged<DateTime> surJour;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final jour = lundi.add(Duration(days: i));
              final rdv = donnees.rendezVousDu(coiffeur, jour);
              final absences = donnees.absencesDu(coiffeur, jour);
              final plages = donnees.plagesDu(coiffeur, jour);
              return Padding(
                padding: const EdgeInsets.only(bottom: Espaces.s3),
                child: Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(rayon),
                    onTap: () => surJour(jour),
                    child: Padding(
                      padding: const EdgeInsets.all(Espaces.s3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDate(jour), style: textes.titleSmall),
                          const SizedBox(height: Espaces.s1),
                          if (plages.isEmpty && rdv.isEmpty)
                            Text('Ne travaille pas', style: textes.bodySmall)
                          else if (rdv.isEmpty)
                            Text(
                              'Aucun rendez-vous · ${plages.map((p) => '${formatHeure(p.debut)}–${formatHeure(p.fin)}').join(', ')}',
                              style: textes.bodySmall,
                            ),
                          for (final a in absences)
                            Text(
                              'Absent ${formatHeure(TimeOfDay.fromDateTime(a.debut))}–${formatHeure(TimeOfDay.fromDateTime(a.fin))}'
                              '${a.motif == null ? '' : ' · ${a.motif}'}',
                              style: textes.bodySmall,
                            ),
                          for (final r in rdv)
                            Text(
                              '${formatHeure(TimeOfDay.fromDateTime(r.debut))}  ${r.clientNom} · ${r.prestation}',
                              style: textes.bodyLarge!.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
