import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import 'formulaire_encaissement.dart';

// Éléments communs aux plannings : axe des heures, colonne d'une journée
// (heures hors horaires grisées, absences, rendez-vous), fiche d'un
// rendez-vous (BF-K2) avec clôture et encaissement (#11).

// 2 px par minute (#79) : un rendez-vous de 30 min tient sur deux lignes
// (heure et client, puis prestation).
const pixelsParMinute = 2.0;
// 60 px (#79) : la pastille de l'heure actuelle (« 18:11 ») y tient.
const largeurAxe = 60.0;

// Apparence d'un état (#64, charte : CouleursStatut). Le libellé est
// toujours écrit, doublé d'une icône : jamais la couleur seule.
class StyleEtat {
  const StyleEtat({
    required this.fond,
    required this.bordure,
    required this.texte,
    required this.libelle,
    required this.icone,
  });
  final Color fond;
  final Color bordure;
  final Color texte;
  // Couleur du libellé de l'état (« En cours », « Absent »).
  final Color libelle;
  final IconData icone;

  factory StyleEtat.de(EtatRendezVous etat) => switch (etat) {
    EtatRendezVous.aVenir => const StyleEtat(
      fond: Couleurs.surface,
      bordure: Couleurs.accent,
      texte: Couleurs.texte,
      libelle: Couleurs.accent,
      icone: Icons.radio_button_unchecked,
    ),
    EtatRendezVous.enCours => const StyleEtat(
      fond: Couleurs.accent,
      bordure: Couleurs.accent,
      texte: Couleurs.surface,
      libelle: Couleurs.surface,
      icone: Icons.schedule,
    ),
    EtatRendezVous.aCloturer => const StyleEtat(
      fond: CouleursStatut.aCloturerFond,
      bordure: CouleursStatut.aCloturerBordure,
      texte: Couleurs.texte,
      libelle: CouleursStatut.aCloturerTexte,
      icone: Icons.pending_outlined,
    ),
    EtatRendezVous.termine => const StyleEtat(
      fond: CouleursStatut.termineFond,
      bordure: CouleursStatut.termineFond,
      texte: Couleurs.texte,
      libelle: Couleurs.texteSecondaire,
      icone: Icons.check,
    ),
    EtatRendezVous.absent => const StyleEtat(
      fond: CouleursStatut.absentFond,
      bordure: CouleursStatut.absentFond,
      texte: Couleurs.texte,
      libelle: CouleursStatut.absentTexte,
      icone: Icons.close,
    ),
  };
}

// Libellé de l'état précédé de son icône (décorative).
class LibelleEtat extends StatelessWidget {
  const LibelleEtat({super.key, required this.etat});
  final EtatRendezVous etat;

  @override
  Widget build(BuildContext context) {
    final style = StyleEtat.de(etat);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(style.icone, size: 18, color: style.libelle),
        ),
        const SizedBox(width: Espaces.s1),
        Text(
          etat.libelle,
          style: Theme.of(
            context,
          ).textTheme.labelLarge!.copyWith(color: style.libelle),
        ),
      ],
    );
  }
}

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
        width: largeurAxe,
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
                final lignes = math.max(
                  1,
                  (contraintes.maxHeight / 24).floor(),
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
                if (lignes < 2) return avecIcone(titre);
                return Column(
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Détail d'un rendez-vous (BF-K2) : client (nom, téléphone), prestation,
// durée, date, heure, statut ; actions de clôture (BF-K3, BF-K4) et, pour le
// gérant, d'encaissement (BF-G4). maintenant : heure du salon, pour savoir si
// le rendez-vous a commencé (la base le vérifie aussi). Renvoie le message à
// afficher après une action réussie, null si rien n'a changé.
Future<String?> afficherRendezVous(
  BuildContext context,
  RendezVous r, {
  required DepotPlanning planning,
  required DateTime maintenant,
  required bool gerant,
  String? coiffeur,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Couleurs.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(rayon)),
    ),
    builder: (_) => _FicheRendezVous(
      rendezVous: r,
      planning: planning,
      maintenant: maintenant,
      gerant: gerant,
      coiffeur: coiffeur,
    ),
  );
}

class _FicheRendezVous extends StatefulWidget {
  const _FicheRendezVous({
    required this.rendezVous,
    required this.planning,
    required this.maintenant,
    required this.gerant,
    this.coiffeur,
  });

  final RendezVous rendezVous;
  final DepotPlanning planning;
  final DateTime maintenant;
  final bool gerant;
  final String? coiffeur;

  @override
  State<_FicheRendezVous> createState() => _FicheRendezVousState();
}

class _FicheRendezVousState extends State<_FicheRendezVous> {
  String? _erreur;
  StatutRendezVous? _enCours;

  RendezVous get _r => widget.rendezVous;

  String get _resume =>
      '${formatDateHeure(_r.debut)} · ${_r.clientNom} · ${_r.prestation}';

  Future<void> _cloturer(StatutRendezVous statut) async {
    final heure = formatHeure(TimeOfDay.fromDateTime(_r.debut));
    final termine = statut == StatutRendezVous.terminee;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(termine ? 'Marquer terminé ?' : 'Client absent ?'),
        content: Text(
          '${termine ? 'Rendez-vous' : 'Absence au rendez-vous'} de $heure '
          'avec ${_r.clientNom}. Ce choix est définitif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(termine ? 'Marquer terminé' : 'Marquer absent'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() {
      _erreur = null;
      _enCours = statut;
    });
    try {
      await widget.planning.cloturer(_r.id, statut);
      if (mounted) {
        Navigator.of(context).pop(
          termine
              ? 'Rendez-vous de $heure marqué terminé.'
              : 'Client du rendez-vous de $heure marqué absent.',
        );
      }
    } on ErreurSalon catch (erreur) {
      if (mounted) {
        setState(() {
          _enCours = null;
          _erreur = erreur.message;
        });
      }
    }
  }

  Future<void> _encaisser() async {
    final correction = _r.montantEncaisse != null;
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormulaireEncaissement(
          planning: widget.planning,
          rendezVousId: _r.id,
          resume: _resume,
          prix: _r.prix,
          montantActuel: _r.montantEncaisse,
        ),
      ),
    );
    if (enregistre == true && mounted) {
      Navigator.of(
        context,
      ).pop(correction ? 'Montant corrigé.' : 'Encaissement enregistré.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = _r;
    final montant = r.montantEncaisse;
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
      ('Prix', formatPrix(r.prix)),
      ('Date', formatDate(r.debut)),
      (
        'Heure',
        '${formatHeure(TimeOfDay.fromDateTime(r.debut))} – ${formatHeure(TimeOfDay.fromDateTime(r.fin))}',
      ),
      if (widget.coiffeur != null) ('Coiffeur', widget.coiffeur!),
      // Même vocabulaire que la liste et la frise (#64).
      ('Statut', r.etat(widget.maintenant).libelle),
      if (widget.gerant && r.statut == StatutRendezVous.terminee)
        ('Encaissé', montant == null ? 'Pas encore' : formatPrix(montant)),
    ];
    final cloturable = r.cloturable(widget.maintenant);
    return SafeArea(
      child: SingleChildScrollView(
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
            if (_erreur != null) ...[
              MessageErreur(_erreur!),
              const SizedBox(height: Espaces.s3),
            ],
            if (cloturable) ...[
              Bouton(
                libelle: 'Terminé',
                libelleChargement: 'Enregistrement…',
                chargement: _enCours == StatutRendezVous.terminee,
                pleineLargeur: true,
                surAppui: () => _cloturer(StatutRendezVous.terminee),
              ),
              const SizedBox(height: Espaces.s2),
              Bouton(
                libelle: 'Client absent',
                libelleChargement: 'Enregistrement…',
                chargement: _enCours == StatutRendezVous.absent,
                secondaire: true,
                pleineLargeur: true,
                surAppui: () => _cloturer(StatutRendezVous.absent),
              ),
              const SizedBox(height: Espaces.s2),
            ] else if (r.statut == StatutRendezVous.confirmee) ...[
              Text(
                'Clôture possible à partir du ${formatDateHeure(r.debut).toLowerCase()}.',
                style: textes.bodySmall,
              ),
              const SizedBox(height: Espaces.s3),
            ],
            if (widget.gerant && r.statut == StatutRendezVous.terminee) ...[
              montant == null
                  ? Bouton(
                      libelle: 'Encaisser',
                      pleineLargeur: true,
                      surAppui: _encaisser,
                    )
                  : Bouton(
                      libelle: 'Corriger le montant',
                      secondaire: true,
                      pleineLargeur: true,
                      surAppui: _encaisser,
                    ),
              const SizedBox(height: Espaces.s2),
            ],
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
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
