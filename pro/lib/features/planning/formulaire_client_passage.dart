import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Nouveau rendez-vous pour un client de passage (#103, options 1A et 2A de
// Sparta) : nom, téléphone facultatif (retrouve la fiche s'il revient),
// prestation, coiffeur (gérant : au choix ou « Peu importe » ; coiffeur :
// lui-même), heure parmi les créneaux libres du jour, la première proposée.
// Renvoie true si le rendez-vous est enregistré.
class FormulaireClientPassage extends StatefulWidget {
  const FormulaireClientPassage({
    super.key,
    required this.planning,
    required this.gerant,
    this.coiffeurId,
  });

  final DepotPlanning planning;
  final bool gerant;
  // Gérant : coiffeur pré-choisi (onglet affiché du planning).
  final String? coiffeurId;

  @override
  State<FormulaireClientPassage> createState() =>
      _FormulaireClientPassageState();
}

class _FormulaireClientPassageState extends State<FormulaireClientPassage> {
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  String? _erreurNom;
  String? _prestation;
  late String? _coiffeur = widget.gerant
      ? widget.coiffeurId
      : widget.planning.moi;
  CreneauLibre? _creneau;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<(DateTime, List<Prestation>, List<Coiffeur>)> _lire() async {
    final resultats = await Future.wait<dynamic>([
      widget.planning.maintenantAuSalon(),
      widget.planning.prestationsActives(),
      if (widget.gerant) widget.planning.coiffeurs(),
    ]);
    final prestations = resultats[1] as List<Prestation>;
    _prestation ??= prestations.isEmpty ? null : prestations.first.id;
    return (
      DateUtils.dateOnly(resultats[0] as DateTime),
      prestations,
      widget.gerant ? resultats[2] as List<Coiffeur> : const <Coiffeur>[],
    );
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    setState(
      () => _erreurNom = nom.isEmpty ? 'Indiquez le nom du client.' : null,
    );
    final creneau = _creneau;
    if (nom.isEmpty || _prestation == null || creneau == null) return;
    setState(() => _enCours = true);
    try {
      await widget.planning.reserverPourClient(
        nom: nom,
        telephone: _telephone.text.trim().isEmpty
            ? null
            : _telephone.text.trim(),
        prestationId: _prestation!,
        creneau: creneau,
        coiffeurId: _coiffeur,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _creneau = null;
      });
      confirmer(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau rendez-vous')),
      body: ListeCharte(
        enfants: [
          Chargement<(DateTime, List<Prestation>, List<Coiffeur>)>(
            lire: _lire,
            afficher: (context, donnees, _) {
              final (jour, prestations, coiffeurs) = donnees;
              if (prestations.isEmpty) {
                return Text(
                  'Aucune prestation proposée pour l\'instant.',
                  style: textes.bodyLarge,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Champ(
                    libelle: 'Nom du client',
                    controleur: _nom,
                    erreur: _erreurNom,
                    capitalisation: TextCapitalization.words,
                    actionClavier: TextInputAction.next,
                  ),
                  const SizedBox(height: Espaces.s4),
                  Champ(
                    libelle: 'Téléphone (facultatif)',
                    controleur: _telephone,
                    aide: 'Retrouve sa fiche s\'il revient.',
                    clavier: TextInputType.phone,
                    actionClavier: TextInputAction.done,
                  ),
                  const SizedBox(height: Espaces.s6),
                  _Titre('Prestation'),
                  Wrap(
                    spacing: Espaces.s2,
                    runSpacing: Espaces.s2,
                    children: [
                      for (final p in prestations)
                        _Pastille(
                          libelle: '${p.nom} · ${formatDuree(p.dureeMinutes)}',
                          choisie: p.id == _prestation,
                          surChoix: () => setState(() {
                            _prestation = p.id;
                            _creneau = null;
                          }),
                        ),
                    ],
                  ),
                  if (widget.gerant) ...[
                    const SizedBox(height: Espaces.s6),
                    _Titre('Coiffeur'),
                    Wrap(
                      spacing: Espaces.s2,
                      runSpacing: Espaces.s2,
                      children: [
                        _Pastille(
                          libelle: 'Peu importe',
                          choisie: _coiffeur == null,
                          surChoix: () => setState(() {
                            _coiffeur = null;
                            _creneau = null;
                          }),
                        ),
                        for (final c in coiffeurs)
                          _Pastille(
                            libelle: c.nom.trim().split(RegExp(r'\s+')).first,
                            avatar: c.nom,
                            choisie: c.id == _coiffeur,
                            surChoix: () => setState(() {
                              _coiffeur = c.id;
                              _creneau = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Espaces.s6),
                  _Titre('Heure, aujourd\'hui'),
                  _Creneaux(
                    // Relu quand la prestation ou le coiffeur change.
                    key: ValueKey('$_prestation-$_coiffeur'),
                    lire: () => widget.planning.creneauxLibres(
                      _prestation!,
                      jour,
                      coiffeurId: _coiffeur,
                    ),
                    choisi: _creneau,
                    surChoix: (c) => setState(() => _creneau = c),
                  ),
                  const SizedBox(height: Espaces.s6),
                  Bouton(
                    libelle: 'Enregistrer le rendez-vous',
                    libelleChargement: 'Enregistrement…',
                    chargement: _enCours,
                    pleineLargeur: true,
                    surAppui: _enregistrer,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.s2),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

// Créneaux libres du jour en pastilles ; le premier est choisi d'office.
class _Creneaux extends StatefulWidget {
  const _Creneaux({
    super.key,
    required this.lire,
    required this.choisi,
    required this.surChoix,
  });
  final Future<List<CreneauLibre>> Function() lire;
  final CreneauLibre? choisi;
  final ValueChanged<CreneauLibre> surChoix;

  @override
  State<_Creneaux> createState() => _CreneauxState();
}

class _CreneauxState extends State<_Creneaux> {
  @override
  Widget build(BuildContext context) {
    return Chargement<List<CreneauLibre>>(
      lire: () async {
        final creneaux = await widget.lire();
        if (creneaux.isNotEmpty && widget.choisi == null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.surChoix(creneaux.first),
          );
        }
        return creneaux;
      },
      afficher: (context, creneaux, _) {
        if (creneaux.isEmpty) {
          return Text(
            'Plus de créneau libre aujourd\'hui pour ce choix.',
            style: Theme.of(context).textTheme.bodyLarge,
          );
        }
        return Wrap(
          spacing: Espaces.s2,
          runSpacing: Espaces.s2,
          children: [
            for (final c in creneaux)
              _Pastille(
                libelle: formatHeure(TimeOfDay.fromDateTime(c.debut)),
                choisie:
                    widget.choisi != null &&
                    widget.choisi!.instant == c.instant,
                surChoix: () => widget.surChoix(c),
              ),
          ],
        );
      },
    );
  }
}

// Pastille de choix sans cadre : choisie en vert sur gris clair.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.libelle,
    required this.choisie,
    required this.surChoix,
    this.avatar,
  });
  final String libelle;
  final bool choisie;
  final VoidCallback surChoix;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: avatar == null ? null : Avatar(nom: avatar!, taille: 24),
      label: Text(libelle),
      labelStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
        color: choisie ? Couleurs.accent : Couleurs.texteSecondaire,
      ),
      selectedColor: Couleurs.separateur,
      backgroundColor: Couleurs.fond,
      side: BorderSide.none,
      showCheckmark: false,
      selected: choisie,
      onSelected: (_) => surChoix(),
    );
  }
}
