import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';

import 'etat_rendez_vous.dart';

// Frise d'une journée (vue horaire) : axe des heures, colonne d'un
// coiffeur (heures hors horaires grisées, absences, rendez-vous), créneaux
// vides à toucher (#104).

// 2 px par minute (#79) : un rendez-vous de 30 min tient sur deux lignes
// (heure et client, puis prestation).
const pixelsParMinute = 2.0;
// 60 px (#79) : la pastille de l'heure actuelle (« 18:11 ») y tient.
const largeurAxe = 60.0;

// Heures affichées (#79) : seulement les horaires du jour des coiffeurs,
// élargies aux rendez-vous qui en sortent, à l'heure pleine. Sans horaire ni
// rendez-vous ce jour-là : 9h-18h. En minutes depuis minuit.
(int, int) fenetreDuJour(
  DonneesPlanning donnees,
  Iterable<String> coiffeurs,
  DateTime jour,
) {
  int? debut;
  int? fin;
  void inclure(int d, int f) {
    debut = debut == null ? d : math.min(debut!, d);
    fin = fin == null ? f : math.max(fin!, f);
  }

  for (final c in coiffeurs) {
    for (final p in donnees.plagesDu(c, jour)) {
      inclure(minutesDuJour(p.debut), minutesDuJour(p.fin));
    }
    for (final r in donnees.rendezVousDu(c, jour)) {
      inclure(
        r.debut.hour * 60 + r.debut.minute,
        memeJour(r.fin, jour) ? r.fin.hour * 60 + r.fin.minute : 24 * 60,
      );
    }
  }
  final d = debut ?? 9 * 60;
  final f = fin ?? 18 * 60;
  return ((d ~/ 60) * 60, math.min(24 * 60, ((f + 59) ~/ 60) * 60));
}

// Résumé d'une journée (#79) : « 3 rendez-vous · 2 h 15 ».
String resumeJournee(List<RendezVous> rendezVous) {
  if (rendezVous.isEmpty) return 'Aucun rendez-vous';
  final minutes = rendezVous.fold<int>(0, (s, r) => s + r.dureeMinutes);
  final nombre = rendezVous.length == 1
      ? '1 rendez-vous'
      : '${rendezVous.length} rendez-vous';
  return '$nombre · ${formatDuree(minutes)}';
}

// Axe des heures ; maintenant (minutes depuis minuit, aujourd'hui seulement) :
// l'heure actuelle écrite dans une pastille rouge, au niveau du trait (#79).
class AxeHeures extends StatelessWidget {
  const AxeHeures({
    super.key,
    required this.debut,
    required this.fin,
    this.maintenant,
  });
  final int debut;
  final int fin;
  final int? maintenant;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: SizedBox(
        // Élargi avec la police du téléphone (#83), jusqu'à 1,8 fois.
        width:
            largeurAxe *
            math.min(1.8, MediaQuery.textScalerOf(context).scale(1)),
        height: (fin - debut) * pixelsParMinute,
        child: Stack(
          children: [
            for (var m = debut; m < fin; m += 60)
              // L'heure pleine s'efface sous la pastille de l'heure actuelle.
              if (maintenant == null || (m - maintenant!).abs() > 15)
                Positioned(
                  top: (m - debut) * pixelsParMinute - 2,
                  left: 0,
                  child: Text(
                    formatHeure(TimeOfDay(hour: m ~/ 60, minute: 0)),
                    style: style,
                  ),
                ),
            if (maintenant case final m? when m >= debut && m <= fin)
              Positioned(
                top: (m - debut) * pixelsParMinute - 12,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Espaces.s1),
                  decoration: BoxDecoration(
                    color: Couleurs.erreur,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    formatHeure(TimeOfDay(hour: m ~/ 60, minute: m % 60)),
                    style: style.copyWith(
                      color: Couleurs.surface,
                      fontWeight: FontWeight.w600,
                      fontVariations: const [FontVariation.weight(600)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Une journée d'un coiffeur. Fond de page hors horaires (une pause, la fenêtre
// suivant ses horaires, #79), `surface` pendant ses plages ; absences en
// bandes ; rendez-vous en blocs à la hauteur de leur durée.
class ColonneJour extends StatelessWidget {
  const ColonneJour({
    super.key,
    required this.jour,
    required this.debut,
    required this.fin,
    required this.plages,
    required this.absences,
    required this.rendezVous,
    required this.surRendezVous,
    required this.maintenant,
    this.surCreneauVide,
  });

  final DateTime jour;
  final int debut;
  final int fin;
  final List<Plage> plages;
  final List<AbsencePlanning> absences;
  final List<RendezVous> rendezVous;
  final ValueChanged<RendezVous> surRendezVous;
  // Heure du salon : état de chaque rendez-vous, trait « maintenant ».
  final DateTime maintenant;
  // Toucher d'un créneau vide (#104) : l'heure touchée, au quart d'heure
  // inférieur, si elle tombe dans les horaires, hors absence, après
  // maintenant. Ailleurs, le toucher ne fait rien.
  final ValueChanged<DateTime>? surCreneauVide;

  double _y(int minutes) =>
      (minutes.clamp(debut, fin) - debut) * pixelsParMinute;

  int _minutes(DateTime d) {
    if (d.isBefore(DateTime(jour.year, jour.month, jour.day))) return 0;
    if (!memeJour(d, jour)) return 24 * 60;
    return d.hour * 60 + d.minute;
  }

  // Heure touchée à la hauteur dy, ou null hors des créneaux réservables.
  DateTime? _creneauTouche(double dy) {
    final m = debut + (dy / pixelsParMinute).floor();
    final touche = DateTime(jour.year, jour.month, jour.day, 0, m);
    final dansHoraires = plages.any(
      (p) => minutesDuJour(p.debut) <= m && m < minutesDuJour(p.fin),
    );
    final absent = absences.any(
      (a) => !touche.isBefore(a.debut) && touche.isBefore(a.fin),
    );
    if (!dansHoraires || absent || !touche.isAfter(maintenant)) return null;
    return DateTime(jour.year, jour.month, jour.day, 0, m - m % 15);
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final hauteur = (fin - debut) * pixelsParMinute;
    return SizedBox(
      height: hauteur,
      child: Stack(
        children: [
          // Hors horaires : fond de page (décoratif).
          Positioned.fill(
            child: ExcludeSemantics(child: Container(color: Couleurs.fond)),
          ),
          for (final p in plages)
            Positioned(
              top: _y(minutesDuJour(p.debut)),
              height: _y(minutesDuJour(p.fin)) - _y(minutesDuJour(p.debut)),
              left: 0,
              right: 0,
              child: Container(color: Couleurs.surface),
            ),
          for (var m = debut; m < fin; m += 60)
            Positioned(
              top: _y(m),
              left: 0,
              right: 0,
              child: Container(height: 1, color: Couleurs.separateur),
            ),
          // Sous les absences et les rendez-vous, qui gardent leur toucher.
          // Hors lecteur d'écran : le bouton « Nouveau rendez-vous » y mène.
          if (surCreneauVide case final surVide?)
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final heure = _creneauTouche(details.localPosition.dy);
                    if (heure != null) surVide(heure);
                  },
                ),
              ),
            ),
          for (final a in absences)
            Positioned(
              top: _y(_minutes(a.debut)),
              height: math.max(24, _y(_minutes(a.fin)) - _y(_minutes(a.debut))),
              left: 0,
              right: 0,
              child: Semantics(
                container: true,
                label:
                    'Absent de ${formatHeure(TimeOfDay.fromDateTime(a.debut))} '
                    'à ${formatHeure(TimeOfDay.fromDateTime(a.fin))}${a.motif == null ? '' : ', ${a.motif}'}',
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(Espaces.s1),
                    decoration: BoxDecoration(
                      color: Couleurs.separateur,
                      border: Border.all(color: Couleurs.bordure),
                    ),
                    child: Text(
                      a.motif == null || a.motif!.isEmpty
                          ? 'Absent'
                          : 'Absent · ${a.motif}',
                      style: textes.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          // Maintenant : trait `erreur` de 3 px avec un point, sous les
          // rendez-vous pour ne pas barrer leur texte ; l'heure est écrite
          // dans l'axe (décoratif, l'état « En cours » est écrit sur le
          // rendez-vous).
          if (memeJour(maintenant, jour) &&
              _minutes(maintenant) >= debut &&
              _minutes(maintenant) <= fin)
            Positioned(
              top: _y(_minutes(maintenant)) - 6,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Couleurs.erreur,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Container(height: 3, color: Couleurs.erreur),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // 2 px de chaque côté (#79) : deux rendez-vous qui se suivent ne
          // se touchent pas.
          for (final r in rendezVous)
            Positioned(
              top: _y(_minutes(r.debut)) + 2,
              height: math.max(
                zoneTactileMin,
                _y(_minutes(r.fin)) - _y(_minutes(r.debut)) - 4,
              ),
              left: Espaces.s1,
              right: Espaces.s1,
              child: _CarteRendezVous(
                rendezVous: r,
                etat: r.etat(maintenant),
                surAppui: () => surRendezVous(r),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarteRendezVous extends StatelessWidget {
  const _CarteRendezVous({
    required this.rendezVous,
    required this.etat,
    required this.surAppui,
  });
  final RendezVous rendezVous;
  final EtatRendezVous etat;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = rendezVous;
    final style = StyleEtat.de(etat);
    final heure = formatHeure(TimeOfDay.fromDateTime(r.debut));
    // Un nœud par rendez-vous (container) : TalkBack les parcourt un à un.
    return Semantics(
      container: true,
      button: true,
      label: '$heure, ${r.clientNom}, ${r.prestation}, ${etat.libelle}',
      // excludeSemantics masque l'action de l'InkWell : elle est redonnée ici,
      // sinon TalkBack annoncerait un bouton impossible à activer.
      onTap: surAppui,
      excludeSemantics: true,
      // Fond doux, sans bordure (#79) ; « à venir » (fond blanc dans la
      // frise) prend une teinte légère de l'accent pour se détacher.
      child: Material(
        color: etat == EtatRendezVous.aVenir
            ? Color.alphaBlend(
                Couleurs.accent.withValues(alpha: 0.08),
                Couleurs.surface,
              )
            : style.fond,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayon),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: surAppui,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.s2,
              vertical: Espaces.s1,
            ),
            // Une ligne par information, selon la hauteur (24 px par ligne,
            // #79) : heure et client ; prestation (précédée de l'icône de
            // l'état) ; état écrit. Jamais la couleur seule.
            child: LayoutBuilder(
              builder: (context, contraintes) {
                // 24 px par ligne, agrandis avec la police du téléphone (#83).
                final hauteurLigne = MediaQuery.textScalerOf(context).scale(24);
                final lignes = math.max(
                  1,
                  (contraintes.maxHeight / hauteurLigne).floor(),
                );
                final titre = Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$heure ',
                        style: textes.labelSmall!.copyWith(color: style.texte),
                      ),
                      TextSpan(
                        text: r.clientNom,
                        style: textes.bodySmall!.copyWith(color: style.texte),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
                Widget avecIcone(Widget texte) => Row(
                  children: [
                    Icon(style.icone, size: 16, color: style.libelle),
                    const SizedBox(width: Espaces.s1),
                    Expanded(child: texte),
                  ],
                );
                final prestation = Text(
                  r.prestation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textes.bodySmall!.copyWith(color: style.texte),
                );
                // Bloc plus court qu'une ligne (15 min, grande police) : le
                // texte dépasse et le bloc le coupe, sans erreur.
                return OverflowBox(
                  alignment: Alignment.topLeft,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: lignes < 2
                      ? avecIcone(titre)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titre,
                            if (lignes == 2)
                              avecIcone(prestation)
                            else ...[
                              prestation,
                              LibelleEtat(etat: etat),
                            ],
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
