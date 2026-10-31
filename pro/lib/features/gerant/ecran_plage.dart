import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Plage horaire d'un coiffeur (#151, option A de Sparta), depuis la fiche
// coiffeur : début et fin, puis les jours cochés (comme la « Récurrence » des
// réveils), avec le raccourci « Du lundi au vendredi ». Un seul
// enregistrement pour tous les jours, tout ou rien (definir_plages).
// Modification d'une plage : ses heures et son jour préremplis ; cocher
// d'autres jours la copie. « Enregistrer » n'est jamais désactivé : ce qui
// manque est dit au-dessus du bouton. Renvoie le message de confirmation,
// null si rien n'a changé.
class EcranPlage extends StatefulWidget {
  const EcranPlage({
    super.key,
    required this.salon,
    required this.coiffeur,
    required this.plagesExistantes,
    this.jour,
    this.plage,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;
  // Plages déjà enregistrées : chevauchement signalé avant l'envoi.
  final List<Plage> plagesExistantes;
  // Jour touché dans la fiche (1 = lundi), coché d'avance.
  final int? jour;
  // Plage modifiée.
  final Plage? plage;

  @override
  State<EcranPlage> createState() => _EcranPlageState();
}

class _EcranPlageState extends State<EcranPlage> {
  late TimeOfDay _debut =
      widget.plage?.debut ?? const TimeOfDay(hour: 9, minute: 0);
  late TimeOfDay _fin =
      widget.plage?.fin ?? const TimeOfDay(hour: 18, minute: 0);
  late final Set<int> _jours = {
    if (widget.plage != null) widget.plage!.jour,
    if (widget.jour != null) widget.jour!,
  };
  String? _erreur;
  bool _enCours = false;

  bool get _modification => widget.plage != null;

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

  void _basculer(int jour) => setState(() {
    _erreur = null;
    if (!_jours.remove(jour)) _jours.add(jour);
  });

  // Du lundi au vendredi : coche les cinq, ou les décoche s'ils l'étaient
  // déjà tous.
  void _semaine() => setState(() {
    _erreur = null;
    const semaine = {1, 2, 3, 4, 5};
    if (_jours.containsAll(semaine)) {
      _jours.removeAll(semaine);
    } else {
      _jours.addAll(semaine);
    }
  });

  // Jours où la plage chevaucherait une plage existante (hors celle
  // modifiée). La base le vérifie aussi.
  List<int> _chevauchements() => [
    for (final jour in _jours.toList()..sort())
      if (widget.plagesExistantes.any(
        (p) =>
            p.id != widget.plage?.id &&
            p.jour == jour &&
            minutesDuJour(p.debut) < minutesDuJour(_fin) &&
            minutesDuJour(_debut) < minutesDuJour(p.fin),
      ))
        jour,
  ];

  Future<void> _enregistrer() async {
    String? erreur;
    if (minutesDuJour(_fin) <= minutesDuJour(_debut)) {
      erreur = 'La fin doit être après le début.';
    } else if (_jours.isEmpty) {
      erreur = 'Choisissez au moins un jour.';
    } else {
      final conflits = _chevauchements();
      if (conflits.isNotEmpty) {
        erreur =
            'Chevauche une plage existante le '
            '${conflits.map((j) => nomsJours[j - 1].toLowerCase()).join(', ')}.';
      }
    }
    setState(() => _erreur = erreur);
    if (erreur != null) return;

    setState(() => _enCours = true);
    final jours = _jours.toList()..sort();
    try {
      await widget.salon.definirPlages(
        widget.coiffeur.id,
        jours: jours,
        debut: _debut,
        fin: _fin,
        remplace: widget.plage?.id,
      );
      if (!mounted) return;
      final heures = '${formatHeure(_debut)} – ${formatHeure(_fin)}';
      final quand = jours.length == 1
          ? nomsJours[jours.single - 1].toLowerCase()
          : '${jours.length} jours';
      Navigator.of(context).pop(switch ((_modification, jours.length > 1)) {
        (true, false) => 'Plage enregistrée : $quand, $heures.',
        (true, true) => 'Plages enregistrées : $quand, $heures.',
        (false, false) => 'Plage ajoutée : $quand, $heures.',
        (false, true) => 'Plages ajoutées : $quand, $heures.',
      });
    } on ErreurSalon catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final semaine = _jours.containsAll(const {1, 2, 3, 4, 5});
    return Scaffold(
      appBar: AppBar(
        title: Text(_modification ? 'Modifier la plage' : 'Nouvelle plage'),
      ),
      body: ListeCharte(
        enfants: [
          Text(widget.coiffeur.nom, style: textes.bodyLarge),
          const SizedBox(height: Espaces.s6),
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
          const SizedBox(height: Espaces.s8),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Jours', style: textes.labelLarge),
                ),
              ),
              TextButton(
                onPressed: _semaine,
                child: Text(semaine ? 'Aucun jour' : 'Du lundi au vendredi'),
              ),
            ],
          ),
          const SizedBox(height: Espaces.s2),
          for (var jour = 1; jour <= 7; jour++)
            _LigneJourCoche(
              nom: nomsJours[jour - 1],
              coche: _jours.contains(jour),
              surAppui: () => _basculer(jour),
            ),
          const SizedBox(height: Espaces.s6),
          if (_erreur != null) ...[
            MessageErreur(_erreur!),
            const SizedBox(height: Espaces.s3),
          ],
          Bouton(
            pleineLargeur: true,
            libelle: _jours.length > 1
                ? 'Enregistrer pour ${_jours.length} jours'
                : 'Enregistrer',
            libelleChargement: 'Enregistrement…',
            chargement: _enCours,
            surAppui: _enregistrer,
          ),
        ],
      ),
    );
  }
}

// Jour à cocher : toute la ligne se touche, coche verte à droite, filet fin
// (même ligne que l'équipe, sans carte). TalkBack lit « Lundi, coché ».
class _LigneJourCoche extends StatelessWidget {
  const _LigneJourCoche({
    required this.nom,
    required this.coche,
    required this.surAppui,
  });
  final String nom;
  final bool coche;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: coche,
      label: nom,
      onTap: surAppui,
      excludeSemantics: true,
      child: InkWell(
        onTap: surAppui,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Couleurs.separateur)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(nom, style: Theme.of(context).textTheme.bodyLarge),
              ),
              if (coche) const Icon(Icons.check, color: Couleurs.accent),
            ],
          ),
        ),
      ),
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
