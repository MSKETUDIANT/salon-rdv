import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import 'elements_planning.dart';

// Planning de toute l'équipe pour le gérant (BF-G5) : une colonne par
// coiffeur sur la journée, axe des heures commun, navigation entre les
// jours. Défilement horizontal si l'équipe ne tient pas en largeur. Depuis la
// fiche d'un rendez-vous : clôture pour un coiffeur et encaissement (#11).
class EcranPlanningEquipe extends StatefulWidget {
  const EcranPlanningEquipe({super.key, required this.planning});
  final DepotPlanning planning;

  @override
  State<EcranPlanningEquipe> createState() => _EcranPlanningEquipeState();
}

class _EcranPlanningEquipeState extends State<EcranPlanningEquipe> {
  static const _largeurColonne = 148.0;
  DateTime? _maintenant;
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
        title: const Text('Planning de l\'équipe'),
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
              key: ValueKey('$_version-$_jour'),
              lire: _lire,
              afficher: (context, resultat, _) {
                final (jour, coiffeurs, donnees) = resultat;
                final ids = [for (final c in coiffeurs) c.id];
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
                    // À 360 px, deux colonnes tiennent ; au-delà, on le dit.
                    if (coiffeurs.length > 2) ...[
                      const SizedBox(height: Espaces.s1),
                      Text(
                        "Faites glisser les colonnes pour voir toute l'équipe.",
                        style: textes.bodySmall,
                      ),
                    ],
                    const SizedBox(height: Espaces.s3),
                    if (coiffeurs.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(rayon),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                const SizedBox(height: 32),
                                AxeHeures(debut: debut, fin: fin),
                              ],
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final c in coiffeurs)
                                      Container(
                                        width: _largeurColonne,
                                        margin: const EdgeInsets.only(
                                          right: Espaces.s1,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            SizedBox(
                                              height: 32,
                                              child: Semantics(
                                                header: true,
                                                child: Text(
                                                  c.nom,
                                                  style: textes.titleSmall,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            ColonneJour(
                                              jour: jour,
                                              debut: debut,
                                              fin: fin,
                                              plages: donnees.plagesDu(
                                                c.id,
                                                jour,
                                              ),
                                              absences: donnees.absencesDu(
                                                c.id,
                                                jour,
                                              ),
                                              rendezVous: donnees.rendezVousDu(
                                                c.id,
                                                jour,
                                              ),
                                              surRendezVous: (r) =>
                                                  _ouvrir(r, c.nom),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: Espaces.s2),
                    Text(
                      'Zones grisées : hors des horaires de chaque coiffeur.',
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
