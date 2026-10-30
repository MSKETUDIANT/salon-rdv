import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Absences d'un coiffeur (BF-G3), fiche coiffeur du gérant.

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
