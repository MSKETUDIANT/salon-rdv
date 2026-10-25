import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';

// Éléments communs aux plannings : axe des heures, colonne d'une journée
// (heures hors horaires grisées, absences, rendez-vous), fiche d'un
// rendez-vous (BF-K2).

const pixelsParMinute = 1.6;
const largeurAxe = 52.0;

// Heures affichées : 8h-20h par défaut, élargies pour montrer toutes les
// plages, absences et rendez-vous du jour. En minutes depuis minuit.
(int, int) fenetreDuJour(
  DonneesPlanning donnees,
  Iterable<String> coiffeurs,
  DateTime jour,
) {
  var debut = 8 * 60;
  var fin = 20 * 60;
  for (final c in coiffeurs) {
    for (final p in donnees.plagesDu(c, jour)) {
      debut = math.min(debut, minutesDuJour(p.debut));
      fin = math.max(fin, minutesDuJour(p.fin));
    }
    for (final r in donnees.rendezVousDu(c, jour)) {
      debut = math.min(debut, r.debut.hour * 60 + r.debut.minute);
      fin = math.max(
        fin,
        memeJour(r.fin, jour) ? r.fin.hour * 60 + r.fin.minute : 24 * 60,
      );
    }
  }
  return ((debut ~/ 60) * 60, math.min(24 * 60, ((fin + 59) ~/ 60) * 60));
}

class AxeHeures extends StatelessWidget {
  const AxeHeures({super.key, required this.debut, required this.fin});
  final int debut;
  final int fin;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: largeurAxe,
        height: (fin - debut) * pixelsParMinute,
        child: Stack(
          children: [
            for (var m = debut; m < fin; m += 60)
              Positioned(
                top: (m - debut) * pixelsParMinute - 2,
                left: 0,
                child: Text(
                  formatHeure(TimeOfDay(hour: m ~/ 60, minute: 0)),
                  style: style,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Une journée d'un coiffeur. Fond `separateur` hors horaires, `surface`
// pendant ses plages ; absences en bandes ; rendez-vous en cartes.
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
  });

  final DateTime jour;
  final int debut;
  final int fin;
  final List<Plage> plages;
  final List<AbsencePlanning> absences;
  final List<RendezVous> rendezVous;
  final ValueChanged<RendezVous> surRendezVous;

  double _y(int minutes) =>
      (minutes.clamp(debut, fin) - debut) * pixelsParMinute;

  int _minutes(DateTime d) {
    if (d.isBefore(DateTime(jour.year, jour.month, jour.day))) return 0;
    if (!memeJour(d, jour)) return 24 * 60;
    return d.hour * 60 + d.minute;
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final hauteur = (fin - debut) * pixelsParMinute;
    return SizedBox(
      height: hauteur,
      child: Stack(
        children: [
          // Hors horaires : grisé (décoratif, charte §2).
          Positioned.fill(
            child: ExcludeSemantics(
              child: Container(color: Couleurs.separateur),
            ),
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
          for (final r in rendezVous)
            Positioned(
              top: _y(_minutes(r.debut)),
              height: math.max(
                zoneTactileMin,
                _y(_minutes(r.fin)) - _y(_minutes(r.debut)),
              ),
              left: Espaces.s1,
              right: Espaces.s1,
              child: _CarteRendezVous(
                rendezVous: r,
                surAppui: () => surRendezVous(r),
              ),
            ),
        ],
      ),
    );
  }
}

class _CarteRendezVous extends StatelessWidget {
  const _CarteRendezVous({required this.rendezVous, required this.surAppui});
  final RendezVous rendezVous;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = rendezVous;
    final heure = formatHeure(TimeOfDay.fromDateTime(r.debut));
    // Un nœud par rendez-vous (container) : TalkBack les parcourt un à un.
    return Semantics(
      container: true,
      button: true,
      label: '$heure, ${r.clientNom}, ${r.prestation}, ${r.statut.libelle}',
      // excludeSemantics masque l'action de l'InkWell : elle est redonnée ici,
      // sinon TalkBack annoncerait un bouton impossible à activer.
      onTap: surAppui,
      excludeSemantics: true,
      child: Material(
        color: Couleurs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayon),
          side: const BorderSide(color: Couleurs.bordure),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: surAppui,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Couleurs.accent, width: 4),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.s2,
              vertical: Espaces.s1,
            ),
            // Autant de lignes que la hauteur du bloc en permet (24 px par
            // ligne), puis points de suspension : jamais de texte coupé.
            child: LayoutBuilder(
              builder: (context, contraintes) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$heure ',
                      style: textes.labelSmall!.copyWith(color: Couleurs.texte),
                    ),
                    TextSpan(
                      text: r.clientNom,
                      style: textes.bodySmall!.copyWith(color: Couleurs.texte),
                    ),
                    TextSpan(
                      text: ' · ${r.prestation}',
                      style: textes.bodySmall,
                    ),
                  ],
                ),
                maxLines: math.max(1, (contraintes.maxHeight / 24).floor()),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Détail d'un rendez-vous (BF-K2) : client (nom, téléphone), prestation,
// durée, date, heure, statut.
Future<void> afficherRendezVous(
  BuildContext context,
  RendezVous r, {
  String? coiffeur,
}) {
  final textes = Theme.of(context).textTheme;
  final lignes = <(String, String)>[
    ('Client', r.clientNom),
    (
      'Téléphone',
      r.clientTelephone == null
          ? 'Non renseigné'
          : formatTelephone(r.clientTelephone!),
    ),
    ('Prestation', r.prestation),
    ('Durée', formatDuree(r.dureeMinutes)),
    ('Date', formatDate(r.debut)),
    (
      'Heure',
      '${formatHeure(TimeOfDay.fromDateTime(r.debut))} – ${formatHeure(TimeOfDay.fromDateTime(r.fin))}',
    ),
    if (coiffeur != null) ('Coiffeur', coiffeur),
    ('Statut', r.statut.libelle),
  ];
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Couleurs.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(rayon)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaces.s4,
          0,
          Espaces.s4,
          Espaces.s6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Rendez-vous', style: textes.headlineSmall),
            ),
            const SizedBox(height: Espaces.s4),
            for (final (terme, valeur) in lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: Espaces.s2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(terme, style: textes.bodySmall),
                    ),
                    Expanded(child: Text(valeur, style: textes.titleSmall)),
                  ],
                ),
              ),
            const SizedBox(height: Espaces.s2),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    ),
  );
}

// Barre de navigation entre les jours (ou les semaines) : précédent, libellé,
// suivant, et « Aujourd'hui ».
class NavigationDates extends StatelessWidget {
  const NavigationDates({
    super.key,
    required this.libelle,
    required this.surPrecedent,
    required this.surSuivant,
    required this.surAujourdhui,
    required this.unite,
  });

  final String libelle;
  final VoidCallback surPrecedent;
  final VoidCallback surSuivant;
  final VoidCallback? surAujourdhui;
  // « jour » ou « semaine », pour les libellés lus par TalkBack.
  final String unite;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: surPrecedent,
              tooltip: unite == 'jour'
                  ? 'Jour précédent'
                  : 'Semaine précédente',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  libelle,
                  style: textes.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            IconButton(
              onPressed: surSuivant,
              tooltip: unite == 'jour' ? 'Jour suivant' : 'Semaine suivante',
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (surAujourdhui != null)
          Center(
            child: TextButton(
              onPressed: surAujourdhui,
              child: const Text('Revenir à aujourd\'hui'),
            ),
          ),
      ],
    );
  }
}
