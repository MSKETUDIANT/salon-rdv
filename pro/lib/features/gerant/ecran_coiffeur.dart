import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Fiche d'un coiffeur pour le gérant : horaires hebdomadaires (plusieurs
// plages par jour), absences et compétences (BF-G1, BF-G3). Chaque
// changement modifie aussitôt les créneaux proposés aux clients.
class EcranCoiffeur extends StatelessWidget {
  const EcranCoiffeur({super.key, required this.salon, required this.coiffeur});
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(coiffeur.nom)),
      body: ListeCharte(
        enfants: [
          _Titre('Horaires'),
          SectionHoraires(salon: salon, coiffeur: coiffeur),
          const SizedBox(height: Espaces.s8),
          _Titre('Absences'),
          SectionAbsences(salon: salon, coiffeur: coiffeur),
          const SizedBox(height: Espaces.s8),
          _Titre('Compétences'),
          SectionCompetences(salon: salon, coiffeur: coiffeur),
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
      padding: const EdgeInsets.only(bottom: Espaces.s3),
      child: Semantics(
        header: true,
        child: Text(texte, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}

// ------------------------------------------------------------
// Horaires
// ------------------------------------------------------------

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

  Future<void> _ajouter() async {
    final plage = await showDialog<_NouvellePlage>(
      context: context,
      builder: (_) => const _DialoguePlage(),
    );
    if (plage == null || !mounted) return;
    try {
      await widget.salon.ajouterPlage(
        widget.coiffeur.id,
        jour: plage.jour,
        debut: plage.debut,
        fin: plage.fin,
      );
      if (!mounted) return;
      confirmer(
        context,
        'Plage ajoutée : ${nomsJours[plage.jour - 1]} ${formatHeure(plage.debut)} – ${formatHeure(plage.fin)}.',
      );
      setState(() => _version++);
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    }
  }

  Future<void> _supprimer(Plage plage) async {
    try {
      await widget.salon.supprimerPlage(plage.id);
      if (!mounted) return;
      confirmer(context, 'Plage supprimée.');
      setState(() => _version++);
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Chargement<List<Plage>>(
          key: ValueKey(_version),
          lire: () => widget.salon.plages(widget.coiffeur.id),
          // Sans carte (#96) : un jour par ligne, filets fins.
          afficher: (context, plages, _) => Column(
            children: [
              for (var jour = 1; jour <= 7; jour++) ...[
                _LigneJour(
                  jour: jour,
                  plages: plages.where((p) => p.jour == jour).toList(),
                  surSupprimer: _supprimer,
                ),
                const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: Espaces.s3),
        Text(
          'Plusieurs plages par jour possibles, sans chevauchement.',
          style: textes.bodySmall,
        ),
        const SizedBox(height: Espaces.s3),
        // Comme « Ajouter une prestation » : bouton vert à sa largeur.
        Align(
          alignment: Alignment.centerLeft,
          child: Bouton(libelle: 'Ajouter une plage', surAppui: _ajouter),
        ),
      ],
    );
  }
}

class _LigneJour extends StatelessWidget {
  const _LigneJour({
    required this.jour,
    required this.plages,
    required this.surSupprimer,
  });
  final int jour;
  final List<Plage> plages;
  final ValueChanged<Plage> surSupprimer;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final nom = nomsJours[jour - 1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
              child: Text(nom, style: textes.titleSmall),
            ),
          ),
          Expanded(
            child: plages.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
                    child: Text('Ne travaille pas', style: textes.bodySmall),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final p in plages)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${formatHeure(p.debut)} – ${formatHeure(p.fin)}',
                                style: textes.bodyLarge!.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => surSupprimer(p),
                              tooltip:
                                  'Supprimer la plage du $nom ${formatHeure(p.debut)} – ${formatHeure(p.fin)}',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Couleurs.texteSecondaire,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _NouvellePlage {
  const _NouvellePlage(this.jour, this.debut, this.fin);
  final int jour;
  final TimeOfDay debut;
  final TimeOfDay fin;
}

// Jour, début et fin d'une nouvelle plage. « Ajouter » n'est jamais
// désactivé : une fin avant le début est signalée.
class _DialoguePlage extends StatefulWidget {
  const _DialoguePlage();

  @override
  State<_DialoguePlage> createState() => _DialoguePlageState();
}

class _DialoguePlageState extends State<_DialoguePlage> {
  int _jour = 1;
  TimeOfDay _debut = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _fin = const TimeOfDay(hour: 18, minute: 0);
  String? _erreur;

  Future<void> _choisir(bool debut) async {
    final choix = await showTimePicker(
      context: context,
      initialTime: debut ? _debut : _fin,
      helpText: debut ? 'Début de la plage' : 'Fin de la plage',
    );
    if (choix == null) return;
    setState(() {
      if (debut) {
        _debut = choix;
      } else {
        _fin = choix;
      }
      _erreur = null;
    });
  }

  void _valider() {
    if (minutesDuJour(_fin) <= minutesDuJour(_debut)) {
      setState(() => _erreur = 'La fin doit être après le début.');
      return;
    }
    Navigator.of(context).pop(_NouvellePlage(_jour, _debut, _fin));
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Nouvelle plage'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Libellé visible repris sur la liste pour TalkBack (« Jour,
          // Lundi »), comme le filtre de l'historique.
          ExcludeSemantics(child: Text('Jour', style: textes.labelLarge)),
          const SizedBox(height: Espaces.s2),
          Semantics(
            label: 'Jour',
            child: DropdownButtonFormField<int>(
              initialValue: _jour,
              items: [
                for (var j = 1; j <= 7; j++)
                  DropdownMenuItem(value: j, child: Text(nomsJours[j - 1])),
              ],
              onChanged: (j) => setState(() => _jour = j ?? _jour),
            ),
          ),
          const SizedBox(height: Espaces.s4),
          _ChoixHeure(
            libelle: 'Début',
            heure: _debut,
            surAppui: () => _choisir(true),
          ),
          const SizedBox(height: Espaces.s3),
          _ChoixHeure(
            libelle: 'Fin',
            heure: _fin,
            surAppui: () => _choisir(false),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: Espaces.s3),
            MessageErreur(_erreur!),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Ajouter')),
      ],
    );
  }
}

// Libellé et bouton qui affiche l'heure choisie (ouvre le sélecteur).
class _ChoixHeure extends StatelessWidget {
  const _ChoixHeure({
    required this.libelle,
    required this.heure,
    required this.surAppui,
  });
  final String libelle;
  final TimeOfDay heure;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(libelle, style: Theme.of(context).textTheme.labelLarge),
        ),
        OutlinedButton(
          // Même largeur pour « 09:00 » et « 18:00 ».
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(104, hauteurBouton),
          ),
          onPressed: surAppui,
          child: Text(
            formatHeure(heure),
            semanticsLabel: '$libelle : ${formatHeure(heure)}, modifier',
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Absences
// ------------------------------------------------------------

class SectionAbsences extends StatefulWidget {
  const SectionAbsences({
    super.key,
    required this.salon,
    required this.coiffeur,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  State<SectionAbsences> createState() => _SectionAbsencesState();
}

class _SectionAbsencesState extends State<SectionAbsences> {
  int _version = 0;

  Future<void> _ajouter() async {
    final enregistree = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FormulaireAbsence(salon: widget.salon, coiffeur: widget.coiffeur),
      ),
    );
    if (enregistree == true && mounted) {
      confirmer(context, 'Absence enregistrée.');
      setState(() => _version++);
    }
  }

  Future<void> _supprimer(Absence absence) async {
    try {
      await widget.salon.supprimerAbsence(absence.id);
      if (!mounted) return;
      confirmer(context, 'Absence supprimée.');
      setState(() => _version++);
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Chargement<List<Absence>>(
          key: ValueKey(_version),
          lire: () => widget.salon.absences(widget.coiffeur.id),
          afficher: (context, absences, _) {
            if (absences.isEmpty) {
              return Text('Aucune absence prévue.', style: textes.bodyLarge);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sans carte (#96) : une absence par ligne, filet fin.
                for (final a in absences) ...[
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Couleurs.separateur),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: Espaces.s2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Du ${formatDateHeure(a.debut).toLowerCase()}',
                                  style: textes.bodyLarge,
                                ),
                                Text(
                                  'au ${formatDateHeure(a.fin).toLowerCase()}',
                                  style: textes.bodyLarge,
                                ),
                                if (a.motif != null && a.motif!.isNotEmpty)
                                  Text(a.motif!, style: textes.bodySmall),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _supprimer(a),
                            tooltip:
                                'Supprimer l\'absence du ${formatDateHeure(a.debut)}',
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Couleurs.texteSecondaire,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: Espaces.s3),
        // Comme « Ajouter une prestation » : bouton vert à sa largeur.
        Align(
          alignment: Alignment.centerLeft,
          child: Bouton(libelle: 'Ajouter une absence', surAppui: _ajouter),
        ),
      ],
    );
  }
}

// Nouvelle absence : début et fin (date et heure), motif facultatif. Si des
// rendez-vous confirmés tombent dedans, le gérant est prévenu sans être
// bloqué (les clients, eux, ne le sont pas : docs/dette-technique.md).
// Les dates et heures saisies sont celles du salon (salons.fuseau_horaire),
// jamais celles du téléphone : « aujourd'hui » est lu au salon, et le dépôt
// convertit en UTC (data/fuseau.dart).
class FormulaireAbsence extends StatelessWidget {
  const FormulaireAbsence({
    super.key,
    required this.salon,
    required this.coiffeur,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Absence de ${coiffeur.nom}')),
      body: ListeCharte(
        enfants: [
          Chargement<DateTime>(
            lire: salon.maintenantAuSalon,
            afficher: (context, maintenant, _) => _SaisieAbsence(
              salon: salon,
              coiffeur: coiffeur,
              maintenant: maintenant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaisieAbsence extends StatefulWidget {
  const _SaisieAbsence({
    required this.salon,
    required this.coiffeur,
    required this.maintenant,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;
  // Date et heure actuelles au salon.
  final DateTime maintenant;

  @override
  State<_SaisieAbsence> createState() => _SaisieAbsenceState();
}

class _SaisieAbsenceState extends State<_SaisieAbsence> {
  late final DateTime _aujourdhui = DateUtils.dateOnly(widget.maintenant);
  late DateTime _debut = _aujourdhui.add(const Duration(days: 1, hours: 9));
  late DateTime _fin = _aujourdhui.add(const Duration(days: 1, hours: 19));
  final _motif = TextEditingController();
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<void> _choisirDate(bool debut) async {
    final actuelle = debut ? _debut : _fin;
    final date = await showDatePicker(
      context: context,
      initialDate: actuelle,
      firstDate: _aujourdhui,
      lastDate: _aujourdhui.add(const Duration(days: 365)),
      helpText: debut ? 'Début de l\'absence' : 'Fin de l\'absence',
    );
    if (date == null) return;
    setState(() {
      final nouvelle = DateTime(
        date.year,
        date.month,
        date.day,
        actuelle.hour,
        actuelle.minute,
      );
      if (debut) {
        _debut = nouvelle;
      } else {
        _fin = nouvelle;
      }
      _erreur = null;
    });
  }

  Future<void> _choisirHeure(bool debut) async {
    final actuelle = debut ? _debut : _fin;
    final heure = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(actuelle),
    );
    if (heure == null) return;
    setState(() {
      final nouvelle = DateTime(
        actuelle.year,
        actuelle.month,
        actuelle.day,
        heure.hour,
        heure.minute,
      );
      if (debut) {
        _debut = nouvelle;
      } else {
        _fin = nouvelle;
      }
      _erreur = null;
    });
  }

  Future<void> _enregistrer() async {
    if (!_fin.isAfter(_debut)) {
      setState(() => _erreur = 'La fin doit être après le début.');
      return;
    }
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    try {
      final rendezVous = await widget.salon.rendezVousPendant(
        widget.coiffeur.id,
        debut: _debut,
        fin: _fin,
      );
      if (!mounted) return;
      if (rendezVous > 0) {
        final confirme = await showDialog<bool>(
          context: context,
          builder: (_) => _AvertissementRendezVous(
            nombre: rendezVous,
            coiffeur: widget.coiffeur.nom,
          ),
        );
        if (confirme != true) {
          if (mounted) setState(() => _enCours = false);
          return;
        }
      }
      final motif = _motif.text.trim();
      await widget.salon.ajouterAbsence(
        widget.coiffeur.id,
        debut: _debut,
        fin: _fin,
        motif: motif.isEmpty ? null : motif,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ErreurSalon catch (erreur) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = erreur.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    Widget ligne(String libelle, bool debut) {
      final d = debut ? _debut : _fin;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(libelle, style: textes.labelLarge),
          const SizedBox(height: Espaces.s2),
          // Date sur la largeur restante, heure sur 104 px comme dans
          // « Nouvelle plage » : mêmes largeurs pour le début et la fin.
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _choisirDate(debut),
                  child: Text(
                    formatDate(d),
                    semanticsLabel:
                        '$libelle, date : ${formatDate(d)}, modifier',
                  ),
                ),
              ),
              const SizedBox(width: Espaces.s3),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(104, hauteurBouton),
                ),
                onPressed: () => _choisirHeure(debut),
                child: Text(
                  formatHeure(TimeOfDay.fromDateTime(d)),
                  semanticsLabel:
                      '$libelle, heure : ${formatHeure(TimeOfDay.fromDateTime(d))}, modifier',
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Heures du salon.', style: textes.bodySmall),
        const SizedBox(height: Espaces.s4),
        ligne('Début', true),
        const SizedBox(height: Espaces.s6),
        ligne('Fin', false),
        const SizedBox(height: Espaces.s6),
        Champ(
          libelle: 'Motif (facultatif)',
          controleur: _motif,
          aide: 'Exemple : congé, formation',
          capitalisation: TextCapitalization.sentences,
          actionClavier: TextInputAction.done,
          surValidation: _enregistrer,
        ),
        const SizedBox(height: Espaces.s6),
        if (_erreur != null) ...[
          MessageErreur(_erreur!),
          const SizedBox(height: Espaces.s3),
        ],
        Bouton(
          libelle: 'Enregistrer l\'absence',
          libelleChargement: 'Enregistrement…',
          chargement: _enCours,
          pleineLargeur: true,
          surAppui: _enregistrer,
        ),
      ],
    );
  }
}

class _AvertissementRendezVous extends StatelessWidget {
  const _AvertissementRendezVous({
    required this.nombre,
    required this.coiffeur,
  });
  final int nombre;
  final String coiffeur;

  @override
  Widget build(BuildContext context) {
    final rdv = nombre == 1
        ? '1 rendez-vous confirmé'
        : '$nombre rendez-vous confirmés';
    return AlertDialog(
      title: const Text('Rendez-vous pendant l\'absence'),
      content: Text(
        '$coiffeur a $rdv pendant cette absence. '
        '${nombre == 1 ? 'Il reste confirmé' : 'Ils restent confirmés'}, et les clients ne sont pas prévenus '
        'automatiquement : pensez à les contacter.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Revenir'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enregistrer quand même'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// Compétences
// ------------------------------------------------------------

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
