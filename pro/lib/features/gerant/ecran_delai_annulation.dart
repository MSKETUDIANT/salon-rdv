import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Délai minimum d'annulation (#118, options 1A et 2a de Sparta), depuis la
// ligne « Annulation » de l'onglet Salon du gérant : jusqu'à quand un client
// peut annuler sur le site. Liste simple, coche sur le délai actuel ; un
// toucher enregistre aussitôt (comme les réglages d'un téléphone). La base
// vérifie le rôle et les bornes (definir_delai_annulation).
class EcranDelaiAnnulation extends StatefulWidget {
  const EcranDelaiAnnulation({super.key, required this.salon});
  final DepotSalon salon;

  @override
  State<EcranDelaiAnnulation> createState() => _EcranDelaiAnnulationState();
}

// Choix proposés, en minutes.
const delaisProposes = [0, 60, 120, 720, 1440, 2880];

class _EcranDelaiAnnulationState extends State<EcranDelaiAnnulation> {
  int _version = 0;
  // Délai en cours d'enregistrement.
  int? _enCours;
  String? _erreur;

  Future<void> _choisir(int minutes) async {
    setState(() {
      _erreur = null;
      _enCours = minutes;
    });
    try {
      await widget.salon.definirDelaiAnnulation(minutes);
      if (!mounted) return;
      setState(() {
        _enCours = null;
        _version++;
      });
      confirmer(context, 'Délai d\'annulation enregistré.');
    } on ErreurSalon catch (erreur) {
      if (mounted) {
        setState(() {
          _enCours = null;
          _erreur = erreur.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Annulation')),
      body: ListeCharte(
        enfants: [
          Text(
            'Jusqu\'à quand un client peut annuler sa réservation sur le site. '
            'Après, il doit contacter le salon.',
            style: textes.bodyLarge,
          ),
          const SizedBox(height: Espaces.s4),
          if (_erreur != null) ...[
            MessageErreur(_erreur!),
            const SizedBox(height: Espaces.s3),
          ],
          Chargement<int>(
            key: ValueKey(_version),
            lire: () async =>
                (await widget.salon.identite()).delaiAnnulationMinutes,
            afficher: (context, actuel, _) => Column(
              children: [
                // Un délai réglé autrement (hors liste) reste visible.
                for (final m in {...delaisProposes, actuel}.toList()..sort())
                  _Choix(
                    libelle: formatDelaiAnnulation(m),
                    choisi: m == actuel,
                    enCours: _enCours == m,
                    surAppui: _enCours != null || m == actuel
                        ? null
                        : () => _choisir(m),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Ligne de choix sans cadre, filet dessous ; coche verte sur le choix actuel,
// jamais la couleur seule (libellé lu « sélectionné » par TalkBack).
class _Choix extends StatelessWidget {
  const _Choix({
    required this.libelle,
    required this.choisi,
    required this.enCours,
    required this.surAppui,
  });
  final String libelle;
  final bool choisi;
  final bool enCours;
  final VoidCallback? surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: true,
      selected: choisi,
      inMutuallyExclusiveGroup: true,
      label: libelle,
      onTap: surAppui,
      excludeSemantics: true,
      child: InkWell(
        onTap: surAppui,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Couleurs.separateur)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  libelle,
                  style: textes.bodyLarge!.copyWith(
                    color: choisi ? Couleurs.accent : Couleurs.texte,
                  ),
                ),
              ),
              if (enCours)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (choisi)
                const Icon(Icons.check, color: Couleurs.accent),
            ],
          ),
        ),
      ),
    );
  }
}
