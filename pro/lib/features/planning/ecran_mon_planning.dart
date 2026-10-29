import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import '../aujourdhui/carte_glissable.dart';
import 'elements_planning.dart';
import 'formulaire_client_passage.dart';

// Planning du coiffeur connecté (BF-K1), comme celui du gérant (#98, option
// A) : bande des jours de la semaine et flèches par semaine, « Aujourd'hui »
// dans la barre du titre, vue horaire ou vue liste ; appui sur un rendez-vous
// pour le détail (BF-K2) et la clôture : terminé, client absent (BF-K3,
// BF-K4). Relu à l'ouverture, à chaque changement de jour, en tirant la liste
// vers le bas.
class EcranMonPlanning extends StatefulWidget {
  const EcranMonPlanning({super.key, required this.planning});
  final DepotPlanning planning;

  @override
  State<EcranMonPlanning> createState() => _EcranMonPlanningState();
}

class _EcranMonPlanningState extends State<EcranMonPlanning> {
  DateTime? _maintenant;
  DateTime? _aujourdhui;
  DateTime? _jour;
  int _version = 0;
  // Vue liste de la journée au lieu de la vue horaire.
  bool _liste = false;

  Future<(DateTime, DonneesPlanning)> _lire() async {
    _maintenant = await widget.planning.maintenantAuSalon();
    _aujourdhui ??= DateUtils.dateOnly(_maintenant!);
    final jour = _jour ??= _aujourdhui!;
    final donnees = await widget.planning.periode(
      jour,
      jour,
      coiffeurId: widget.planning.moi,
    );
    return (jour, donnees);
  }

  void _allerA(DateTime jour) {
    if (_jour != null && memeJour(jour, _jour!)) return;
    setState(() {
      _jour = jour;
      _version++;
    });
  }

  void _actualiser() => setState(() => _version++);

  // Fiche d'un rendez-vous ; après une clôture, message et relecture.
  Future<void> _ouvrir(RendezVous r) async {
    final message = await afficherRendezVous(
      context,
      r,
      planning: widget.planning,
      maintenant: _maintenant!,
      gerant: false,
    );
    if (message == null || !mounted) return;
    confirmer(context, message);
    _actualiser();
  }

  // Client de passage (#103) : formulaire, puis message et relecture.
  Future<void> _nouveauRendezVous() async {
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FormulaireClientPassage(planning: widget.planning, gerant: false),
      ),
    );
    if (enregistre != true || !mounted) return;
    confirmer(context, 'Rendez-vous ajouté.');
    _actualiser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          // Retour au jour actuel, seulement hors de ce jour (comme le gérant).
          if (_jour != null && !memeJour(_jour!, _aujourdhui!))
            TextButton(
              onPressed: () => _allerA(_aujourdhui!),
              child: const Text("Aujourd'hui"),
            ),
          IconButton(
            onPressed: () => setState(() => _liste = !_liste),
            tooltip: _liste ? 'Vue horaire' : 'Vue liste',
            icon: Icon(_liste ? Icons.schedule : Icons.view_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nouveauRendezVous,
        icon: const Icon(Icons.add),
        label: const Text('Nouveau rendez-vous'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _actualiser(),
        child: ListView(
          // Tirer vers le bas marche aussi quand la journée tient à l'écran.
          physics: const AlwaysScrollableScrollPhysics(),
          // Mêmes marges que ListeCharte (ui/composants.dart), sans marge en
          // haut : la date suit le titre de près.
          padding: const EdgeInsets.fromLTRB(
            Espaces.s4,
            0,
            Espaces.s4,
            // Place sous le dernier rendez-vous : le bouton flottant
            // « Nouveau rendez-vous » ne le cache pas (#103).
            96,
          ),
          children: [
            Chargement<(DateTime, DonneesPlanning)>(
              silhouette: const SilhouettePlanning(),
              key: ValueKey(_version),
              lire: _lire,
              afficher: (context, resultat, _) {
                final (jour, donnees) = resultat;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Flèches par semaine ; le jour se choisit dans la bande.
                    NavigationDates(
                      unite: 'semaine',
                      libelle: formatDate(jour),
                      surPrecedent: () =>
                          _allerA(jour.subtract(const Duration(days: 7))),
                      surSuivant: () =>
                          _allerA(jour.add(const Duration(days: 7))),
                      surAujourdhui: null,
                    ),
                    BandeJours(
                      jour: jour,
                      aujourdhui: _aujourdhui!,
                      surChoix: _allerA,
                    ),
                    const SizedBox(height: Espaces.s3),
                    _VueJour(
                      jour: jour,
                      donnees: donnees,
                      coiffeur: widget.planning.moi ?? '',
                      maintenant: _maintenant!,
                      liste: _liste,
                      surRendezVous: _ouvrir,
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
    required this.maintenant,
    required this.liste,
    required this.surRendezVous,
  });
  final DateTime jour;
  final DonneesPlanning donnees;
  final String coiffeur;
  final DateTime maintenant;
  final bool liste;
  final ValueChanged<RendezVous> surRendezVous;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final rdv = donnees.rendezVousDu(coiffeur, jour);
    final plages = donnees.plagesDu(coiffeur, jour);
    final (debut, fin) = fenetreDuJour(donnees, [coiffeur], jour);
    final resume = resumeJournee(rdv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plages.isEmpty ? '$resume · ne travaille pas ce jour-là' : resume,
          style: textes.bodyLarge,
        ),
        if (liste) ...[
          const SizedBox(height: Espaces.s2),
          for (final r in rdv)
            CarteGlissable(
              rendezVous: r,
              etat: r.etat(maintenant),
              glissable: false,
              surAppui: () => surRendezVous(r),
              surGeste: (_) {},
            ),
        ]
        // Jour de repos (#79) : le message seul, sans grille.
        else if (plages.isNotEmpty || rdv.isNotEmpty) ...[
          const SizedBox(height: Espaces.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(rayon),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AxeHeures(
                  debut: debut,
                  fin: fin,
                  maintenant: memeJour(maintenant, jour)
                      ? maintenant.hour * 60 + maintenant.minute
                      : null,
                ),
                Expanded(
                  child: ColonneJour(
                    jour: jour,
                    debut: debut,
                    fin: fin,
                    plages: plages,
                    absences: donnees.absencesDu(coiffeur, jour),
                    rendezVous: rdv,
                    surRendezVous: surRendezVous,
                    maintenant: maintenant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
