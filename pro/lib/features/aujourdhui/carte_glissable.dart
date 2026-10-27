import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../data/planning.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import '../planning/elements_planning.dart';

// Rendez-vous de la liste « Aujourd'hui » (#64). Appui : la fiche. Une fois
// commencé (glissable), glisser à droite : « Terminé » ; à gauche : « Client
// absent ». Petite vibration au seuil, vibration de confirmation au geste.
// TalkBack : les deux clôtures sont des actions du nœud (et restent dans la
// fiche). indice : la carte glisse un peu une fois, pour montrer le geste
// (sauf si le téléphone demande moins d'animations).
class CarteGlissable extends StatefulWidget {
  const CarteGlissable({
    super.key,
    required this.rendezVous,
    required this.etat,
    required this.glissable,
    required this.surAppui,
    required this.surGeste,
    this.coiffeur,
    this.indice = false,
  });

  final RendezVous rendezVous;
  final EtatRendezVous etat;
  final bool glissable;
  final VoidCallback surAppui;
  final ValueChanged<StatutRendezVous> surGeste;
  // Gérant : nom du coiffeur, ajouté à la ligne.
  final String? coiffeur;
  final bool indice;

  @override
  State<CarteGlissable> createState() => _CarteGlissableState();
}

class _CarteGlissableState extends State<CarteGlissable>
    with SingleTickerProviderStateMixin {
  late final _indice = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  // Aller-retour vers la droite, de 64 px au plus.
  late final _decalage = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 64,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(tween: ConstantTween<double>(64), weight: 15),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 64,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 45,
    ),
  ]).animate(_indice);
  Timer? _attente;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.indice &&
        widget.glissable &&
        !_indice.isAnimating &&
        !_indice.isCompleted &&
        !MediaQuery.of(context).disableAnimations) {
      _attente ??= Timer(const Duration(milliseconds: 600), _indice.forward);
    }
  }

  @override
  void dispose() {
    _attente?.cancel();
    _indice.dispose();
    super.dispose();
  }

  void _geste(StatutRendezVous statut) {
    HapticFeedback.mediumImpact();
    widget.surGeste(statut);
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = widget.rendezVous;
    final style = StyleEtat.de(widget.etat);
    final heure = formatHeure(TimeOfDay.fromDateTime(r.debut));
    final detail = [
      r.prestation,
      if (widget.coiffeur != null) widget.coiffeur!,
    ].join(' · ');

    final carte = Material(
      color: style.fond,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon),
        side: BorderSide(color: style.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.surAppui,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.s4,
              vertical: Espaces.s2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    heure,
                    style: textes.labelLarge!.copyWith(
                      color: style.texte,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.clientNom,
                        style: textes.titleSmall!.copyWith(color: style.texte),
                      ),
                      Text(
                        detail,
                        style: textes.bodyMedium!.copyWith(color: style.texte),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Espaces.s2),
                LibelleEtat(etat: widget.etat),
              ],
            ),
          ),
        ),
      ),
    );

    // Fond révélé par le geste (et par l'indice), texte blanc.
    Widget fond(bool termine) => Container(
      decoration: BoxDecoration(
        color: termine ? Couleurs.accent : CouleursStatut.absentTexte,
        borderRadius: BorderRadius.circular(rayon),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Espaces.s4),
      alignment: termine ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(termine ? Icons.check : Icons.close, color: Couleurs.surface),
          const SizedBox(width: Espaces.s2),
          Text(
            termine ? 'Terminé' : 'Client absent',
            style: textes.labelLarge!.copyWith(color: Couleurs.surface),
          ),
        ],
      ),
    );

    final contenu = AnimatedBuilder(
      animation: _decalage,
      child: carte,
      builder: (context, carte) => _decalage.value == 0
          ? carte!
          : Stack(
              children: [
                Positioned.fill(child: ExcludeSemantics(child: fond(true))),
                Transform.translate(
                  offset: Offset(_decalage.value, 0),
                  child: carte,
                ),
              ],
            ),
    );

    return Semantics(
      container: true,
      button: true,
      label: [
        heure,
        r.clientNom,
        r.prestation,
        if (widget.coiffeur != null) widget.coiffeur!,
        widget.etat.libelle,
      ].join(', '),
      onTap: widget.surAppui,
      customSemanticsActions: widget.glissable
          ? {
              const CustomSemanticsAction(label: 'Terminé'): () =>
                  _geste(StatutRendezVous.terminee),
              const CustomSemanticsAction(label: 'Client absent'): () =>
                  _geste(StatutRendezVous.absent),
            }
          : null,
      excludeSemantics: true,
      child: Dismissible(
        key: ValueKey('${r.id}-${widget.etat.name}'),
        direction: widget.glissable
            ? DismissDirection.horizontal
            : DismissDirection.none,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.35,
          DismissDirection.endToStart: 0.35,
        },
        onUpdate: (details) {
          if (details.reached && !details.previousReached) {
            HapticFeedback.selectionClick();
          }
        },
        // La carte revient à sa place : la liste se met à jour avec l'état.
        confirmDismiss: (sens) async {
          _geste(
            sens == DismissDirection.startToEnd
                ? StatutRendezVous.terminee
                : StatutRendezVous.absent,
          );
          return false;
        },
        background: fond(true),
        secondaryBackground: fond(false),
        child: contenu,
      ),
    );
  }
}
