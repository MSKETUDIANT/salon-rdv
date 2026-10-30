import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Horaires hebdomadaires d'un coiffeur (BF-G1), fiche coiffeur du gérant.

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
