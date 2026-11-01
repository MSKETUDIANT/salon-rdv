import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Horaires de la semaine d'un coiffeur (#151, option B de Sparta), depuis la
// fiche coiffeur : les 7 jours sur un écran, un interrupteur par jour, les
// heures modifiables d'un toucher, et par jour un menu « Ajouter une pause » /
// « Copier vers d'autres jours… ». Un seul « Enregistrer », toujours visible
// en bas, pour toute la semaine (definir_semaine, tout ou rien).
// Mieux que les concurrents (Fresha : un écran par jour ; Google : pas de
// copie) : la copie en un geste, un jour activé reprend les heures du jour
// travaillé le plus proche, les erreurs dites sous le jour, et une alerte si
// on quitte sans enregistrer. Renvoie le message de confirmation, null si
// rien n'a été enregistré.
class EcranSemaine extends StatefulWidget {
  const EcranSemaine({
    super.key,
    required this.salon,
    required this.coiffeur,
    required this.plages,
  });
  final DepotSalon salon;
  final Coiffeur coiffeur;
  // Plages enregistrées, point de départ de l'écran.
  final List<Plage> plages;

  @override
  State<EcranSemaine> createState() => _EcranSemaineState();
}

typedef _Heures = (TimeOfDay, TimeOfDay);

const _parDefaut = (
  TimeOfDay(hour: 9, minute: 0),
  TimeOfDay(hour: 18, minute: 0),
);

class _EcranSemaineState extends State<EcranSemaine> {
  // Plages par jour (1 = lundi), gardées quand on éteint un jour : le
  // rallumer les retrouve.
  late final Map<int, List<_Heures>> _plages = {
    for (var jour = 1; jour <= 7; jour++)
      jour: [
        for (final p
            in widget.plages.where((p) => p.jour == jour).toList()
              ..sort((a, b) => minutesDuJour(a.debut) - minutesDuJour(b.debut)))
          (p.debut, p.fin),
      ],
  };
  late final Set<int> _actifs = {for (final p in widget.plages) p.jour};
  late final String _depart = _signature();
  String? _erreur;
  bool _enCours = false;

  // Semaine telle qu'elle serait enregistrée : sert à savoir si quelque
  // chose a changé.
  List<PlageSemaine> _semaine() => [
    for (final jour in _actifs.toList()..sort())
      for (final (debut, fin) in _plages[jour]!)
        (jour: jour, debut: debut, fin: fin),
  ];

  String _signature() => _semaine()
      .map((p) => '${p.jour} ${formatHeure(p.debut)} ${formatHeure(p.fin)}')
      .join(';');

  bool get _modifie => _signature() != _depart;

  // Erreur d'un jour travaillé : fin avant le début, ou plages qui se
  // chevauchent. La base le vérifie aussi.
  String? _erreurDuJour(int jour) {
    if (!_actifs.contains(jour)) return null;
    final plages = [..._plages[jour]!]
      ..sort((a, b) => minutesDuJour(a.$1) - minutesDuJour(b.$1));
    for (final (debut, fin) in plages) {
      if (minutesDuJour(fin) <= minutesDuJour(debut)) {
        return 'La fin doit être après le début.';
      }
    }
    for (var i = 1; i < plages.length; i++) {
      if (minutesDuJour(plages[i].$1) < minutesDuJour(plages[i - 1].$2)) {
        return 'Deux plages se chevauchent.';
      }
    }
    return null;
  }

  void _changer(VoidCallback action) => setState(() {
    action();
    _erreur = null;
  });

  // Jour allumé sans plage : celles du jour travaillé le plus proche avant
  // lui (sinon après), sinon 9 h – 18 h.
  void _basculer(int jour, bool actif) => _changer(() {
    if (!actif) {
      _actifs.remove(jour);
      return;
    }
    _actifs.add(jour);
    if (_plages[jour]!.isNotEmpty) return;
    final voisins = [
      for (var d = jour - 1; d >= 1; d--) d,
      for (var d = jour + 1; d <= 7; d++) d,
    ];
    final modele = voisins
        .where((d) => _actifs.contains(d) && _plages[d]!.isNotEmpty)
        .firstOrNull;
    _plages[jour] = modele == null ? [_parDefaut] : [..._plages[modele]!];
  });

  Future<void> _choisirHeure(int jour, int rang, bool debut) async {
    final (d, f) = _plages[jour]![rang];
    final nom = nomsJours[jour - 1];
    final choix = await showTimePicker(
      context: context,
      initialTime: debut ? d : f,
      helpText: debut ? '$nom : début' : '$nom : fin',
    );
    if (choix == null) return;
    _changer(() => _plages[jour]![rang] = debut ? (choix, f) : (d, choix));
  }

  // Pause d'une heure dans la dernière plage du jour : 12 h – 13 h si elle y
  // tient, sinon au milieu. Plage trop courte (moins de 2 h) : dit.
  void _ajouterPause(int jour) {
    final plages = _plages[jour]!;
    final (debut, fin) = plages.last;
    final d = minutesDuJour(debut);
    final f = minutesDuJour(fin);
    if (f - d < 120) {
      confirmer(context, 'Plage trop courte pour une pause (2 h au moins).');
      return;
    }
    var pause = 12 * 60;
    if (!(d < pause && pause + 60 < f)) pause = ((d + f) ~/ 2 ~/ 60) * 60;
    if (!(d < pause && pause + 60 < f)) pause = d + 60;
    TimeOfDay heure(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
    _changer(() {
      plages
        ..removeLast()
        ..add((debut, heure(pause)))
        ..add((heure(pause + 60), fin));
    });
  }

  void _retirer(int jour, int rang) =>
      _changer(() => _plages[jour]!.removeAt(rang));

  Future<void> _copier(int source) async {
    final cibles = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FeuilleCopie(source: source),
    );
    if (cibles == null || cibles.isEmpty) return;
    _changer(() {
      for (final jour in cibles) {
        _actifs.add(jour);
        _plages[jour] = [..._plages[source]!];
      }
    });
    if (mounted) {
      confirmer(
        context,
        'Horaires du ${nomsJours[source - 1].toLowerCase()} copiés vers '
        '${cibles.length} jour${cibles.length > 1 ? 's' : ''}.',
      );
    }
  }

  Future<void> _enregistrer() async {
    final enErreur = [
      for (var jour = 1; jour <= 7; jour++)
        if (_erreurDuJour(jour) != null) jour,
    ];
    if (enErreur.isNotEmpty) {
      setState(
        () => _erreur =
            'Corrigez les heures du '
            '${enErreur.map((j) => nomsJours[j - 1].toLowerCase()).join(', ')}.',
      );
      return;
    }
    if (!_modifie) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    try {
      await widget.salon.definirSemaine(widget.coiffeur.id, _semaine());
      if (!mounted) return;
      Navigator.of(context).pop('Horaires enregistrés.');
    } on ErreurSalon catch (e) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = e.message;
      });
    }
  }

  // Retour avec des changements : on demande avant de les perdre.
  Future<void> _quitter() async {
    final quitter = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter sans enregistrer ?'),
        content: const Text('Les changements des horaires seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (quitter == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_modifie || _enCours,
      onPopInvokedWithResult: (sorti, _) {
        if (!sorti) _quitter();
      },
      child: Scaffold(
        // Titre court : entier même à 200 % de police.
        appBar: AppBar(title: const Text('Horaires')),
        body: ListeCharte(
          enfants: [
            Text(
              'Semaine de ${widget.coiffeur.nom}. Touchez une heure pour la '
              'changer.',
              style: textes.bodySmall,
            ),
            const SizedBox(height: Espaces.s3),
            for (var jour = 1; jour <= 7; jour++)
              _Jour(
                nom: nomsJours[jour - 1],
                actif: _actifs.contains(jour),
                plages: _plages[jour]!,
                erreur: _erreurDuJour(jour),
                surBascule: (actif) => _basculer(jour, actif),
                surHeure: (rang, debut) => _choisirHeure(jour, rang, debut),
                surRetirer: (rang) => _retirer(jour, rang),
                surPause: () => _ajouterPause(jour),
                surCopier: () => _copier(jour),
              ),
          ],
        ),
        // Toujours visible : on voit les heures en enregistrant.
        bottomNavigationBar: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Couleurs.fond,
              border: Border(top: BorderSide(color: Couleurs.separateur)),
            ),
            padding: const EdgeInsets.fromLTRB(
              Espaces.s4,
              Espaces.s3,
              Espaces.s4,
              Espaces.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_erreur != null) ...[
                  MessageErreur(_erreur!),
                  const SizedBox(height: Espaces.s2),
                ],
                Bouton(
                  pleineLargeur: true,
                  libelle: 'Enregistrer',
                  libelleChargement: 'Enregistrement…',
                  chargement: _enCours,
                  surAppui: _enregistrer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Un jour. Repos : une seule ligne (nom, « Ne travaille pas »,
// interrupteur). Travaillé : nom et interrupteur, puis une ligne par plage
// (deux boutons d'heure, × s'il y en a plusieurs, menu ⋮ sur la première).
// Interrupteurs alignés à droite ; filet fin, sans carte.
class _Jour extends StatelessWidget {
  const _Jour({
    required this.nom,
    required this.actif,
    required this.plages,
    required this.erreur,
    required this.surBascule,
    required this.surHeure,
    required this.surRetirer,
    required this.surPause,
    required this.surCopier,
  });
  final String nom;
  final bool actif;
  final List<_Heures> plages;
  final String? erreur;
  final ValueChanged<bool> surBascule;
  final void Function(int rang, bool debut) surHeure;
  final ValueChanged<int> surRetirer;
  final VoidCallback surPause;
  final VoidCallback surCopier;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Espaces.s1),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Couleurs.separateur)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom, état et interrupteur lus ensemble : « Lundi, activé ».
          MergeSemantics(
            child: Row(
              children: [
                SizedBox(
                  width: 104,
                  child: Text(nom, style: textes.titleSmall),
                ),
                Expanded(
                  child: actif
                      ? const SizedBox.shrink()
                      : Text('Ne travaille pas', style: textes.bodySmall),
                ),
                Switch(value: actif, onChanged: surBascule),
              ],
            ),
          ),
          if (actif) ...[
            for (final (rang, (debut, fin)) in plages.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Espaces.s2),
                child: Row(
                  children: [
                    // Grande police : la fin passe dessous, jamais coupée.
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: Espaces.s2,
                        children: [
                          _BoutonHeure(
                            heure: debut,
                            libelle: '$nom, début',
                            surAppui: () => surHeure(rang, true),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Espaces.s2,
                            ),
                            child: ExcludeSemantics(child: Text('–')),
                          ),
                          _BoutonHeure(
                            heure: fin,
                            libelle: '$nom, fin',
                            surAppui: () => surHeure(rang, false),
                          ),
                        ],
                      ),
                    ),
                    if (plages.length > 1)
                      IconButton(
                        onPressed: () => surRetirer(rang),
                        tooltip:
                            'Retirer la plage ${formatHeure(debut)} – '
                            '${formatHeure(fin)} du $nom',
                        icon: const Icon(
                          Icons.close,
                          color: Couleurs.texteSecondaire,
                        ),
                      ),
                    if (rang == 0)
                      PopupMenuButton<VoidCallback>(
                        tooltip: 'Autres actions du $nom',
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) => action(),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: surPause,
                            child: const Text('Ajouter une pause'),
                          ),
                          PopupMenuItem(
                            value: surCopier,
                            child: const Text("Copier vers d'autres jours…"),
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),
            if (erreur != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Espaces.s2),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    erreur!,
                    style: textes.bodyLarge!.copyWith(color: Couleurs.erreur),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// Heure d'une plage, qui ouvre le sélecteur. Même largeur pour toutes.
class _BoutonHeure extends StatelessWidget {
  const _BoutonHeure({
    required this.heure,
    required this.libelle,
    required this.surAppui,
  });
  final TimeOfDay heure;
  final String libelle;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        // Étroit : deux plages, × et ⋮ tiennent sur une ligne à 360 dp.
        minimumSize: const Size(80, hauteurBouton),
        padding: const EdgeInsets.symmetric(horizontal: Espaces.s3),
      ),
      onPressed: surAppui,
      child: Text(
        formatHeure(heure),
        semanticsLabel: '$libelle : ${formatHeure(heure)}, modifier',
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}

// Copie d'un jour vers d'autres : raccourcis, puis les autres jours à cocher.
class _FeuilleCopie extends StatefulWidget {
  const _FeuilleCopie({required this.source});
  final int source;

  @override
  State<_FeuilleCopie> createState() => _FeuilleCopieState();
}

class _FeuilleCopieState extends State<_FeuilleCopie> {
  final _cibles = <int>{};

  void _raccourci(Iterable<int> jours) => setState(() {
    _cibles
      ..clear()
      ..addAll(jours.where((j) => j != widget.source));
  });

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final nom = nomsJours[widget.source - 1].toLowerCase();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Espaces.s4,
          0,
          Espaces.s4,
          Espaces.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Copier les horaires du $nom vers…',
                style: textes.titleMedium,
              ),
            ),
            const SizedBox(height: Espaces.s2),
            Wrap(
              spacing: Espaces.s2,
              children: [
                TextButton(
                  onPressed: () => _raccourci(const [1, 2, 3, 4, 5]),
                  child: const Text('Du lundi au vendredi'),
                ),
                TextButton(
                  onPressed: () => _raccourci(const [1, 2, 3, 4, 5, 6, 7]),
                  child: const Text('Tous les jours'),
                ),
              ],
            ),
            for (var jour = 1; jour <= 7; jour++)
              if (jour != widget.source)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(nomsJours[jour - 1]),
                  value: _cibles.contains(jour),
                  onChanged: (coche) => setState(() {
                    if (coche == true) {
                      _cibles.add(jour);
                    } else {
                      _cibles.remove(jour);
                    }
                  }),
                ),
            const SizedBox(height: Espaces.s3),
            Bouton(
              pleineLargeur: true,
              libelle: _cibles.isEmpty
                  ? 'Copier'
                  : 'Copier vers ${_cibles.length} jour'
                        '${_cibles.length > 1 ? 's' : ''}',
              surAppui: () => Navigator.of(context).pop({..._cibles}),
            ),
          ],
        ),
      ),
    );
  }
}
