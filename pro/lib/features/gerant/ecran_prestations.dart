import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Catalogue du salon (BF-G2) : créer, modifier, désactiver une prestation.
// Pas de suppression : une prestation désactivée n'est plus proposée aux
// clients mais reste dans l'historique des réservations.
class EcranPrestations extends StatefulWidget {
  const EcranPrestations({super.key, required this.salon});
  final DepotSalon salon;

  @override
  State<EcranPrestations> createState() => _EcranPrestationsState();
}

class _EcranPrestationsState extends State<EcranPrestations> {
  // Change à chaque modification : relit la liste.
  int _version = 0;

  Future<void> _ouvrirFormulaire([Prestation? prestation]) async {
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            FormulairePrestation(salon: widget.salon, prestation: prestation),
      ),
    );
    if (enregistre != true || !mounted) return;
    confirmer(
      context,
      prestation == null ? 'Prestation ajoutée.' : 'Prestation modifiée.',
    );
    setState(() => _version++);
  }

  Future<void> _basculer(Prestation p) async {
    try {
      await widget.salon.changerActivation(p.id, active: !p.active);
      if (!mounted) return;
      confirmer(
        context,
        p.active
            ? '${p.nom} désactivée : elle n\'est plus proposée aux clients.'
            : '${p.nom} réactivée : elle est de nouveau proposée.',
      );
      setState(() => _version++);
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Prestations')),
      body: ListeCharte(
        enfants: [
          Bouton(
            libelle: 'Ajouter une prestation',
            pleineLargeur: true,
            surAppui: () => _ouvrirFormulaire(),
          ),
          const SizedBox(height: Espaces.s6),
          Chargement<List<Prestation>>(
            key: ValueKey(_version),
            lire: widget.salon.prestations,
            afficher: (context, prestations, _) {
              if (prestations.isEmpty) {
                return Text(
                  'Aucune prestation pour l\'instant.',
                  style: textes.bodyLarge,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final p in prestations) ...[
                    _CartePrestation(
                      prestation: p,
                      surModifier: () => _ouvrirFormulaire(p),
                      surBasculer: () => _basculer(p),
                    ),
                    const SizedBox(height: Espaces.s3),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CartePrestation extends StatelessWidget {
  const _CartePrestation({
    required this.prestation,
    required this.surModifier,
    required this.surBasculer,
  });

  final Prestation prestation;
  final VoidCallback surModifier;
  final VoidCallback surBasculer;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final p = prestation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaces.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.nom, style: textes.titleMedium),
            const SizedBox(height: Espaces.s1),
            Text(
              '${formatPrix(p.prix)} · ${formatDuree(p.dureeMinutes)}',
              style: textes.bodyLarge!.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (!p.active) ...[
              const SizedBox(height: Espaces.s1),
              Text(
                'Désactivée : plus proposée aux clients',
                style: textes.bodySmall,
              ),
            ],
            const SizedBox(height: Espaces.s2),
            Wrap(
              spacing: Espaces.s6,
              children: [
                TextButton(
                  onPressed: surModifier,
                  child: Text('Modifier', semanticsLabel: 'Modifier ${p.nom}'),
                ),
                TextButton(
                  onPressed: surBasculer,
                  child: Text(
                    p.active ? 'Désactiver' : 'Réactiver',
                    semanticsLabel:
                        '${p.active ? 'Désactiver' : 'Réactiver'} ${p.nom}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Création ou modification d'une prestation : nom, prix (DT), durée (min).
// Renvoie true si la prestation a été enregistrée.
class FormulairePrestation extends StatefulWidget {
  const FormulairePrestation({super.key, required this.salon, this.prestation});
  final DepotSalon salon;
  final Prestation? prestation;

  @override
  State<FormulairePrestation> createState() => _FormulairePrestationState();
}

class _FormulairePrestationState extends State<FormulairePrestation> {
  late final _nom = TextEditingController(text: widget.prestation?.nom);
  late final _prix = TextEditingController(
    text: widget.prestation == null
        ? ''
        : formatPrix(widget.prestation!.prix).replaceAll(' DT', ''),
  );
  late final _duree = TextEditingController(
    text: widget.prestation?.dureeMinutes.toString(),
  );
  final _focusPrix = FocusNode();
  final _focusDuree = FocusNode();
  String? _erreurNom;
  String? _erreurPrix;
  String? _erreurDuree;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _prix.dispose();
    _duree.dispose();
    _focusPrix.dispose();
    _focusDuree.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();
    final prix = lirePrix(_prix.text);
    final duree = lireDuree(_duree.text);
    setState(() {
      _erreur = null;
      _erreurNom = nom.isEmpty ? 'Indiquez le nom de la prestation.' : null;
      _erreurPrix = prix == null
          ? 'Indiquez un prix positif, par exemple 35 ou 10,500.'
          : null;
      _erreurDuree = duree == null
          ? 'Indiquez une durée en minutes, plus de 0.'
          : null;
    });
    if (_erreurNom != null || _erreurPrix != null || _erreurDuree != null) {
      return;
    }

    setState(() => _enCours = true);
    try {
      final existante = widget.prestation;
      if (existante == null) {
        await widget.salon.creerPrestation(
          nom: nom,
          prix: prix!,
          dureeMinutes: duree!,
        );
      } else {
        await widget.salon.modifierPrestation(
          existante.id,
          nom: nom,
          prix: prix!,
          dureeMinutes: duree!,
        );
      }
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
    final creation = widget.prestation == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          creation ? 'Nouvelle prestation' : 'Modifier la prestation',
        ),
      ),
      body: ListeCharte(
        enfants: [
          Champ(
            libelle: 'Nom',
            controleur: _nom,
            erreur: _erreurNom,
            capitalisation: TextCapitalization.sentences,
            actionClavier: TextInputAction.next,
            surValidation: _focusPrix.requestFocus,
          ),
          const SizedBox(height: Espaces.s4),
          Champ(
            libelle: 'Prix (DT)',
            controleur: _prix,
            erreur: _erreurPrix,
            aide: 'Exemple : 35 ou 10,500',
            focus: _focusPrix,
            clavier: const TextInputType.numberWithOptions(decimal: true),
            actionClavier: TextInputAction.next,
            surValidation: _focusDuree.requestFocus,
          ),
          const SizedBox(height: Espaces.s4),
          Champ(
            libelle: 'Durée (minutes)',
            controleur: _duree,
            erreur: _erreurDuree,
            aide: 'Exemple : 45',
            focus: _focusDuree,
            clavier: TextInputType.number,
            actionClavier: TextInputAction.done,
            surValidation: _enregistrer,
          ),
          if (!creation) ...[
            const SizedBox(height: Espaces.s4),
            Text(
              'Les rendez-vous déjà pris gardent leur heure de fin. '
              'La nouvelle durée vaut pour les prochaines réservations.',
              style: textes.bodySmall,
            ),
          ],
          const SizedBox(height: Espaces.s6),
          if (_erreur != null) ...[
            MessageErreur(_erreur!),
            const SizedBox(height: Espaces.s3),
          ],
          Bouton(
            libelle: 'Enregistrer',
            libelleChargement: 'Enregistrement…',
            chargement: _enCours,
            pleineLargeur: true,
            surAppui: _enregistrer,
          ),
        ],
      ),
    );
  }
}
