import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import 'ecran_plage.dart';

// Horaires hebdomadaires d'un coiffeur (BF-G1), fiche coiffeur du gérant.
// Ajout et modification sur l'écran de la plage (#151) : plusieurs jours
// d'un coup.

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
  // Plages lues, passées à l'écran (chevauchement signalé avant l'envoi).
  List<Plage> _plages = const [];

  // Nouvelle plage (jour coché d'avance si un jour a été touché) ou
  // modification.
  Future<void> _ouvrir({int? jour, Plage? plage}) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EcranPlage(
          salon: widget.salon,
          coiffeur: widget.coiffeur,
          plagesExistantes: _plages,
          jour: jour,
          plage: plage,
        ),
      ),
    );
    if (!mounted || message == null) return;
    confirmer(context, message);
    setState(() => _version++);
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
          lire: () async =>
              _plages = await widget.salon.plages(widget.coiffeur.id),
          // Sans carte (#96) : un jour par ligne, filets fins.
          afficher: (context, plages, _) => Column(
            children: [
              for (var jour = 1; jour <= 7; jour++) ...[
                _LigneJour(
                  jour: jour,
                  plages: plages.where((p) => p.jour == jour).toList(),
                  surSupprimer: _supprimer,
                  surNouvelle: () => _ouvrir(jour: jour),
                  surModifier: (p) => _ouvrir(plage: p),
                ),
                const Divider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: Espaces.s3),
        Text(
          'Touchez un jour pour le modifier. Plusieurs plages par jour '
          'possibles, sans chevauchement.',
          style: textes.bodySmall,
        ),
        const SizedBox(height: Espaces.s3),
        // Comme « Ajouter une prestation » : bouton vert à sa largeur.
        Align(
          alignment: Alignment.centerLeft,
          child: Bouton(libelle: 'Ajouter une plage', surAppui: _ouvrir),
        ),
      ],
    );
  }
}

// Un jour (#151) : une ligne par plage, le nom du jour sur la première.
// Toucher la ligne ouvre la plage à modifier ; un jour sans plage ouvre une
// nouvelle plage, ce jour coché. La corbeille reste à part (TalkBack lit les
// deux séparément).
class _LigneJour extends StatelessWidget {
  const _LigneJour({
    required this.jour,
    required this.plages,
    required this.surSupprimer,
    required this.surNouvelle,
    required this.surModifier,
  });
  final int jour;
  final List<Plage> plages;
  final ValueChanged<Plage> surSupprimer;
  final VoidCallback surNouvelle;
  final ValueChanged<Plage> surModifier;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final nom = nomsJours[jour - 1];
    String heures(Plage p) => '${formatHeure(p.debut)} – ${formatHeure(p.fin)}';
    final style = textes.bodyLarge!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget ligne({
      required bool premiere,
      required String libelle,
      required VoidCallback surAppui,
      required Widget contenu,
      Widget? fin,
    }) => Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: libelle,
            onTap: surAppui,
            excludeSemantics: true,
            child: InkWell(
              onTap: surAppui,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: premiere
                          ? Text(nom, style: textes.titleSmall)
                          : null,
                    ),
                    Expanded(child: contenu),
                  ],
                ),
              ),
            ),
          ),
        ),
        ?fin,
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.s1),
      child: Column(
        children: [
          if (plages.isEmpty)
            ligne(
              premiere: true,
              libelle: '$nom, ne travaille pas, ajouter une plage',
              surAppui: surNouvelle,
              contenu: Text('Ne travaille pas', style: textes.bodySmall),
            ),
          for (final (i, p) in plages.indexed)
            ligne(
              premiere: i == 0,
              libelle: '$nom, ${heures(p)}, modifier',
              surAppui: () => surModifier(p),
              contenu: Text(heures(p), style: style),
              fin: IconButton(
                onPressed: () => surSupprimer(p),
                tooltip: 'Supprimer la plage du $nom ${heures(p)}',
                icon: const Icon(
                  Icons.delete_outline,
                  color: Couleurs.texteSecondaire,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
