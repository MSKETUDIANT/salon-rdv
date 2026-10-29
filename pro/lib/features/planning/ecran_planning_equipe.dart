import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../aujourdhui/carte_glissable.dart';
import 'elements_planning.dart';

// Planning de toute l'équipe pour le gérant (BF-G5) : la frise d'un coiffeur
// sur la journée, choisi par des pastilles en haut (#64), son résumé dessous
// (#79), bande des jours de la semaine et flèches par semaine (#80), vue
// horaire ou vue liste (icône dans la barre du titre, #80) ; tirer vers le bas
// pour actualiser. Depuis la fiche d'un rendez-vous : clôture pour un coiffeur et
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
  // Vue liste de la journée (#80) au lieu de la vue horaire.
  bool _liste = false;

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

  void _choisirJour(DateTime jour) {
    if (memeJour(jour, _jour!)) return;
    setState(() {
      _jour = jour;
      _version++;
    });
  }

  void _actualiser() => setState(() => _version++);

  // Premier mot du nom : « Patron Démo » → « Patron ».
  static String _prenom(String nom) => nom.trim().split(RegExp(r'\s+')).first;

  // Jour de repos : pas d'horaires et aucun rendez-vous.
  static bool _repos(DonneesPlanning donnees, String coiffeur, DateTime jour) =>
      donnees.plagesDu(coiffeur, jour).isEmpty &&
      donnees.rendezVousDu(coiffeur, jour).isEmpty;

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
          // Retour au jour actuel, seulement hors de ce jour (#80, option A).
          if (_jour != null && !memeJour(_jour!, _aujourdhui!))
            TextButton(
              onPressed: () => setState(() {
                _jour = _aujourdhui;
                _version++;
              }),
              child: const Text("Aujourd'hui"),
            ),
          IconButton(
            onPressed: () => setState(() => _liste = !_liste),
            tooltip: _liste ? 'Vue horaire' : 'Vue liste',
            icon: Icon(_liste ? Icons.schedule : Icons.view_list),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _actualiser(),
        child: ListView(
          // Tirer vers le bas marche aussi quand la journée tient à l'écran.
          physics: const AlwaysScrollableScrollPhysics(),
          // Mêmes marges que ListeCharte (ui/composants.dart).
          // Pas de marge en haut (#79) : la date suit le titre de près.
          padding: const EdgeInsets.fromLTRB(
            Espaces.s4,
            0,
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Flèches par semaine ; le jour se choisit dans la bande.
                    NavigationDates(
                      unite: 'semaine',
                      libelle: formatDate(jour),
                      surPrecedent: () => _deplacer(-7),
                      surSuivant: () => _deplacer(7),
                      // « Aujourd'hui » est dans la barre du titre (#80).
                      surAujourdhui: null,
                    ),
                    BandeJours(
                      jour: jour,
                      aujourdhui: _aujourdhui!,
                      surChoix: _choisirJour,
                    ),
                    if (coiffeurs.isEmpty) ...[
                      const SizedBox(height: Espaces.s2),
                      Text(
                        'Aucun coiffeur dans ce salon.',
                        style: textes.bodyLarge,
                      ),
                    ],
                    if (choisi != null) ...[
                      const SizedBox(height: Espaces.s3),
                      // Un coiffeur à la fois : pastilles de choix, défilantes
                      // si l'équipe ne tient pas en largeur.
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final c in coiffeurs) ...[
                              // Vert en petite touche (#79) : coiffeur choisi
                              // en vert sur gris clair, sans cadre.
                              // Prénom et petit avatar (#80, choix de Sparta).
                              ChoiceChip(
                                avatar: Avatar(nom: c.nom, taille: 24),
                                label: Text(_prenom(c.nom)),
                                labelStyle: textes.labelLarge!.copyWith(
                                  color: c.id == choisi.id
                                      ? Couleurs.accent
                                      : Couleurs.texteSecondaire,
                                ),
                                selectedColor: Couleurs.separateur,
                                backgroundColor: Couleurs.fond,
                                side: BorderSide.none,
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
                        donnees.plagesDu(choisi.id, jour).isEmpty
                            ? '${resumeJournee(donnees.rendezVousDu(choisi.id, jour))} · ne travaille pas ce jour-là'
                            : resumeJournee(
                                donnees.rendezVousDu(choisi.id, jour),
                              ),
                        style: textes.bodyLarge,
                      ),
                      // Jour de repos (#79) : le message seul, sans grille.
                      if (_liste) ...[
                        const SizedBox(height: Espaces.s2),
                        for (final r in donnees.rendezVousDu(choisi.id, jour))
                          CarteGlissable(
                            rendezVous: r,
                            etat: r.etat(_maintenant!),
                            glissable: false,
                            surAppui: () => _ouvrir(r, choisi.nom),
                            surGeste: (_) {},
                          ),
                      ] else if (!_repos(donnees, choisi.id, jour)) ...[
                        const SizedBox(height: Espaces.s2),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(rayon),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AxeHeures(
                                debut: debut,
                                fin: fin,
                                maintenant: memeJour(_maintenant!, jour)
                                    ? _maintenant!.hour * 60 +
                                          _maintenant!.minute
                                    : null,
                              ),
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
                    ],
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
