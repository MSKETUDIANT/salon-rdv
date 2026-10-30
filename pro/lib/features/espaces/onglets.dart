import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/roles.dart';
import '../../data/salon.dart';
import '../../data/session.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../gerant/ecran_equipe.dart';
import '../gerant/ecran_prestations.dart';
import '../historique/ecran_historique.dart';
import 'ecran_mes_infos.dart';
import 'ecran_mot_de_passe.dart';

// Onglets « Salon » et « Profil » de la barre du bas (#64, #73, #81).

class _Section extends StatelessWidget {
  const _Section(this.titre);
  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.s2),
      child: Semantics(
        header: true,
        child: Text(titre, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

// Gérant (#81) : identité du salon en tête (nom, adresse, horaires déduits de
// ceux des coiffeurs, option A de Sparta), puis listes à icônes avec un
// chiffre : Activité (historique), Configuration (prestations, équipe).
class OngletSalonGerant extends StatelessWidget {
  const OngletSalonGerant({
    super.key,
    required this.salon,
    required this.planning,
  });
  final DepotSalon salon;
  final DepotPlanning planning;

  Future<_ResumeSalon> _lire() async {
    final maintenant = await planning.maintenantAuSalon();
    final jour = DateUtils.dateOnly(maintenant);
    final lundi = jour.subtract(Duration(days: jour.weekday - 1));
    final resultats = await Future.wait<dynamic>([
      salon.identite(),
      salon.prestations(),
      salon.coiffeurs(),
      planning.periode(lundi, lundi.add(const Duration(days: 6))),
    ]);
    final identite = resultats[0] as ({String nom, String? adresse});
    final semaine = resultats[3] as DonneesPlanning;
    return _ResumeSalon(
      nom: identite.nom,
      adresse: identite.adresse,
      jour: jour,
      ouverture: horairesDuSalon(semaine.plages),
      prestations: (resultats[1] as List<Prestation>)
          .where((p) => p.active)
          .length,
      coiffeurs: (resultats[2] as List<Coiffeur>).length,
      rendezVousSemaine: semaine.rendezVous.length,
      aEncaisser: semaine.rendezVous
          .where(
            (r) =>
                r.statut == StatutRendezVous.terminee &&
                r.montantEncaisse == null,
          )
          .length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    void ouvrir(Widget ecran) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));
    return Scaffold(
      body: ListeCharte(
        haut: Espaces.s6,
        enfants: [
          Text('Espace gérant', style: textes.bodySmall),
          Chargement<_ResumeSalon>(
            lire: _lire,
            afficher: (context, r, _) {
              final aujourdhui = r.ouverture[r.jour.weekday];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      r.nom,
                      style: textes.headlineMedium!.copyWith(height: 1.2),
                    ),
                  ),
                  const SizedBox(height: Espaces.s2),
                  if (r.adresse case final adresse? when adresse.isNotEmpty)
                    _Info(icone: Icons.place_outlined, texte: adresse),
                  _Info(
                    icone: Icons.schedule,
                    texte: aujourdhui == null
                        ? 'Fermé aujourd\'hui'
                        : 'Ouvert aujourd\'hui · ${formatHeure(aujourdhui.$1)} – ${formatHeure(aujourdhui.$2)}',
                    detail: resumeHoraires(r.ouverture),
                  ),
                  const SizedBox(height: Espaces.s6),
                  const _Section('Activité'),
                  _Ligne(
                    icone: Icons.history,
                    titre: 'Historique',
                    aDroite: r.aEncaisser > 0
                        ? '${r.aEncaisser} à encaisser'
                        : '${r.rendezVousSemaine} cette semaine',
                    accent: r.aEncaisser > 0,
                    surAppui: () => ouvrir(EcranHistorique(planning: planning)),
                  ),
                  const SizedBox(height: Espaces.s6),
                  const _Section('Configuration'),
                  _Ligne(
                    icone: Icons.content_cut,
                    titre: 'Prestations',
                    aDroite: r.prestations == 1
                        ? '1 prestation'
                        : '${r.prestations} prestations',
                    surAppui: () => ouvrir(EcranPrestations(salon: salon)),
                  ),
                  _Ligne(
                    icone: Icons.group_outlined,
                    titre: 'Équipe',
                    aDroite: r.coiffeurs == 1
                        ? '1 coiffeur'
                        : '${r.coiffeurs} coiffeurs',
                    surAppui: () => ouvrir(EcranEquipe(salon: salon)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ResumeSalon {
  const _ResumeSalon({
    required this.nom,
    required this.adresse,
    required this.jour,
    required this.ouverture,
    required this.prestations,
    required this.coiffeurs,
    required this.rendezVousSemaine,
    required this.aEncaisser,
  });
  final String nom;
  final String? adresse;
  final DateTime jour;
  final Map<int, (TimeOfDay, TimeOfDay)> ouverture;
  final int prestations;
  final int coiffeurs;
  final int rendezVousSemaine;
  final int aEncaisser;
}

// Horaires du salon déduits de ceux des coiffeurs (#81, option A) : pour
// chaque jour (1 = lundi), de la première arrivée au dernier départ. Jour
// absent : fermé.
Map<int, (TimeOfDay, TimeOfDay)> horairesDuSalon(List<PlageCoiffeur> plages) {
  final jours = <int, (int, int)>{};
  for (final p in plages) {
    final d = p.plage.debut.hour * 60 + p.plage.debut.minute;
    final f = p.plage.fin.hour * 60 + p.plage.fin.minute;
    final actuel = jours[p.plage.jour];
    jours[p.plage.jour] = actuel == null
        ? (d, f)
        : (actuel.$1 < d ? actuel.$1 : d, actuel.$2 > f ? actuel.$2 : f);
  }
  TimeOfDay heure(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
  return {
    for (final MapEntry(key: j, value: (d, f)) in jours.entries)
      j: (heure(d), heure(f)),
  };
}

// Semaine, un groupe de jours aux mêmes horaires par ligne (comme Google
// Maps ; jamais de plage coupée en fin de ligne) : « Lun 10:00 – 18:00 »,
// « Mar–Sam 09:00 – 19:00 », « Dim fermé ».
String resumeHoraires(Map<int, (TimeOfDay, TimeOfDay)> ouverture) {
  const noms = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  String plage(int j) {
    final o = ouverture[j];
    return o == null ? 'fermé' : '${formatHeure(o.$1)} – ${formatHeure(o.$2)}';
  }

  final morceaux = <String>[];
  var debut = 1;
  for (var j = 1; j <= 7; j++) {
    if (j < 7 && plage(j + 1) == plage(j)) continue;
    final jours = debut == j
        ? noms[j - 1]
        : '${noms[debut - 1]}–${noms[j - 1]}';
    morceaux.add('$jours ${plage(j)}');
    debut = j + 1;
  }
  return morceaux.join('\n');
}

// Ligne d'information de l'en-tête : icône, texte, détail en petit dessous.
class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.texte, this.detail});
  final IconData icone;
  final String texte;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Espaces.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icone, color: Couleurs.texteSecondaire)),
          const SizedBox(width: Espaces.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texte, style: textes.bodyLarge),
                if (detail != null) Text(detail!, style: textes.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Coiffeur : ses horaires de la semaine et ses absences des 30 prochains
// jours, en lecture seule (le gérant les modifie).
class OngletSalonCoiffeur extends StatelessWidget {
  const OngletSalonCoiffeur({super.key, required this.planning});
  final DepotPlanning planning;

  Future<(DateTime, DonneesPlanning)> _lire() async {
    final jour = DateUtils.dateOnly(await planning.maintenantAuSalon());
    final donnees = await planning.periode(
      jour,
      jour.add(const Duration(days: 30)),
      coiffeurId: planning.moi,
    );
    return (jour, donnees);
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      body: ListeCharte(
        haut: Espaces.s6,
        enfants: [
          // Titre aux proportions de l'onglet Salon du gérant (#100).
          Text('Espace coiffeur', style: textes.bodySmall),
          Semantics(
            header: true,
            child: Text(
              'Salon',
              style: textes.headlineMedium!.copyWith(height: 1.2),
            ),
          ),
          const SizedBox(height: Espaces.s6),
          Chargement<(DateTime, DonneesPlanning)>(
            lire: _lire,
            afficher: (context, resultat, _) {
              final (jour, donnees) = resultat;
              final moi = planning.moi ?? '';
              final lundi = lundiDe(jour);
              final absences = [
                for (final a in donnees.absences)
                  if (a.coiffeurId == moi) a,
              ]..sort((a, b) => a.debut.compareTo(b.debut));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Section('Mes horaires'),
                  // Sans carte (#100) : un jour par ligne, filets fins.
                  for (var i = 0; i < 7; i++) ...[
                    _LigneHoraire(
                      jour: nomsJours[i],
                      plages: donnees.plagesDu(
                        moi,
                        lundi.add(Duration(days: i)),
                      ),
                    ),
                    const Divider(),
                  ],
                  const SizedBox(height: Espaces.s6),
                  const _Section('Mes absences (30 prochains jours)'),
                  if (absences.isEmpty)
                    Text('Aucune absence prévue.', style: textes.bodyLarge)
                  else
                    // Sans carte (#100) : une absence par ligne, filet fin.
                    for (final a in absences)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Couleurs.separateur),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Espaces.s3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Du ${formatDateHeure(a.debut).toLowerCase()}',
                                style: textes.bodyLarge,
                              ),
                              Text(
                                'au ${formatDateHeure(a.fin).toLowerCase()}',
                                style: textes.bodyLarge,
                              ),
                              if (a.motif != null && a.motif!.isNotEmpty)
                                Text(a.motif!, style: textes.bodySmall),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: Espaces.s4),
                  Text(
                    'Horaires et absences sont modifiés par le gérant du salon.',
                    style: textes.bodySmall,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LigneHoraire extends StatelessWidget {
  const _LigneHoraire({required this.jour, required this.plages});
  final String jour;
  final List<Plage> plages;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 104, child: Text(jour, style: textes.titleSmall)),
          Expanded(
            child: plages.isEmpty
                ? Text('Ne travaille pas', style: textes.bodySmall)
                : Text(
                    plages
                        .map(
                          (p) =>
                              '${formatHeure(p.debut)} – ${formatHeure(p.fin)}',
                        )
                        .join('\n'),
                    style: textes.bodyLarge!.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Profil (#73, maquette A de #66) : grand avatar rond, nom, e-mail et rôle ;
// choix de l'espace pour un gérant qui est aussi coiffeur ; entrées à venir
// (#74) à leur place, désactivées ; « À propos » et la version ; déconnexion
// en bas. Remplace l'onglet « Compte » (#64).
class OngletProfil extends StatefulWidget {
  const OngletProfil({
    super.key,
    required this.compte,
    required this.espace,
    required this.planning,
    required this.surDeconnexion,
    required this.changerMotDePasse,
    this.autreEspace,
    this.surBascule,
  });

  final String compte;
  final Espace espace;
  final DepotPlanning planning;
  final Espace? autreEspace;
  final ValueChanged<Espace>? surBascule;
  final VoidCallback surDeconnexion;
  final Future<ErreurMotDePasse?> Function(String actuel, String nouveau)
  changerMotDePasse;

  @override
  State<OngletProfil> createState() => _OngletProfilState();
}

class _OngletProfilState extends State<OngletProfil> {
  // Nom du compte, relu après « Modifier mes infos » (#106).
  late Future<String?> _nom = _lireNom();

  Future<String?> _lireNom() =>
      widget.planning.monNom().catchError((_) => null);

  // Mes infos (#106) : écran dédié, puis nom relu et message au retour.
  Future<void> _mesInfos(BuildContext context) async {
    final nom = await _nom;
    if (!context.mounted) return;
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranMesInfos(
          planning: widget.planning,
          compte: widget.compte,
          nom: nom,
        ),
      ),
    );
    if (enregistre == true && context.mounted) {
      setState(() {
        _nom = _lireNom();
      });
      confirmer(context, 'Infos enregistrées.');
    }
  }

  // Mot de passe (#107) : écran dédié, puis message au retour.
  Future<void> _motDePasse(BuildContext context) async {
    final change = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranMotDePasse(changer: widget.changerMotDePasse),
      ),
    );
    if (change == true && context.mounted) {
      confirmer(context, 'Mot de passe modifié.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final autre = widget.autreEspace;
    final roles = autre == null
        ? (widget.espace == Espace.gerant ? 'Gérant' : 'Coiffeur')
        : 'Gérant et coiffeur';
    return Scaffold(
      body: ListeCharte(
        haut: Espaces.s6,
        enfants: [
          // Le nom se lit en tâche de fond ; en attendant (ou sans nom),
          // l'e-mail tient lieu de nom. Tout tient à 360 × 640 : bascule et
          // déconnexion visibles sans défiler (#41).
          FutureBuilder<String?>(
            future: _nom,
            builder: (context, lecture) {
              final nom = lecture.data?.trim();
              final affiche = nom == null || nom.isEmpty ? widget.compte : nom;
              return SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Avatar(nom: affiche, taille: 80),
                    const SizedBox(height: Espaces.s2),
                    Semantics(
                      header: true,
                      child: Text(
                        affiche,
                        textAlign: TextAlign.center,
                        style: textes.headlineSmall!.copyWith(height: 1.3),
                      ),
                    ),
                    if (affiche != widget.compte)
                      Text(widget.compte, style: textes.bodySmall),
                    const SizedBox(height: Espaces.s1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espaces.s3,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Couleurs.separateur,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(roles, style: textes.labelLarge),
                    ),
                  ],
                ),
              );
            },
          ),
          // Choix de l'espace, juste sous l'en-tête : seulement pour un compte
          // gérant et coiffeur.
          if (autre != null) ...[
            const SizedBox(height: Espaces.s4),
            Semantics(
              container: true,
              label: 'Espace',
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<Espace>(
                  segments: const [
                    ButtonSegment(value: Espace.gerant, label: Text('Gérant')),
                    ButtonSegment(
                      value: Espace.coiffeur,
                      label: Text('Coiffeur'),
                    ),
                  ],
                  selected: {widget.espace},
                  showSelectedIcon: false,
                  // Vert en petite touche (#83, option 2A) : choix en vert
                  // sur gris clair, l'autre en gris, bord très léger.
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (etats) => etats.contains(WidgetState.selected)
                          ? Couleurs.separateur
                          : Couleurs.fond,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (etats) => etats.contains(WidgetState.selected)
                          ? Couleurs.accent
                          : Couleurs.texteSecondaire,
                    ),
                    side: const WidgetStatePropertyAll(
                      BorderSide(color: Couleurs.separateur),
                    ),
                  ),
                  onSelectionChanged: (choix) =>
                      widget.surBascule?.call(choix.first),
                ),
              ),
            ),
          ],
          const SizedBox(height: Espaces.s4),
          _Ligne(
            icone: Icons.edit_outlined,
            titre: 'Modifier mes infos',
            surAppui: () => _mesInfos(context),
          ),
          _Ligne(
            icone: Icons.lock_outline,
            titre: 'Mot de passe',
            surAppui: () => _motDePasse(context),
          ),
          const _Ligne(
            icone: Icons.info_outline,
            titre: 'À propos',
            aDroite: 'Version $versionApp',
          ),
          const SizedBox(height: Espaces.s3),
          Center(
            child: TextButton.icon(
              onPressed: widget.surDeconnexion,
              // Rouge, sans le soulignement vert des boutons texte (#83).
              style: TextButton.styleFrom(
                foregroundColor: Couleurs.erreur,
                textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                  decoration: TextDecoration.none,
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ),
        ],
      ),
    );
  }
}

// Ligne du profil, sans cadre : icône, titre, texte à droite, filet dessous.
// Les entrées à venir (#74) sont affichées, sans action.
class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.titre,
    this.aDroite = '',
    this.surAppui,
    this.accent = false,
  });
  final IconData icone;
  final String titre;
  final String aDroite;
  // Ligne qui ouvre un écran (chevron) ; sans action : entrée à venir.
  final VoidCallback? surAppui;
  // Chiffre qui appelle une action (« 4 à encaisser ») : en ambre.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      button: surAppui != null,
      label: aDroite.isEmpty ? titre : '$titre, $aDroite',
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
              Icon(icone, color: Couleurs.texteSecondaire),
              const SizedBox(width: Espaces.s3),
              Expanded(child: Text(titre, style: textes.bodyLarge)),
              Text(
                aDroite,
                style: accent
                    ? textes.labelLarge!.copyWith(
                        color: CouleursStatut.aCloturerTexte,
                      )
                    : textes.bodySmall,
              ),
              if (surAppui != null)
                const Icon(
                  Icons.chevron_right,
                  color: Couleurs.texteSecondaire,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
