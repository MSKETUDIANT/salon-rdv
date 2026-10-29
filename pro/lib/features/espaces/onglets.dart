import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/roles.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../gerant/ecran_equipe.dart';
import '../gerant/ecran_prestations.dart';
import '../historique/ecran_historique.dart';

// Onglets « Salon » et « Compte » de la barre du bas (#64).

// En-tête d'un onglet : petit sur-titre et titre en Newsreader.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.surTitre, required this.titre});
  final Widget surTitre;
  final String titre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        surTitre,
        const SizedBox(height: Espaces.s1),
        Semantics(
          header: true,
          child: Text(titre, style: Theme.of(context).textTheme.displaySmall),
        ),
        const SizedBox(height: Espaces.s6),
      ],
    );
  }
}

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

// Gérant : activité (historique) et configuration (prestations, équipe).
class OngletSalonGerant extends StatelessWidget {
  const OngletSalonGerant({
    super.key,
    required this.salon,
    required this.planning,
  });
  final DepotSalon salon;
  final DepotPlanning planning;

  @override
  Widget build(BuildContext context) {
    void ouvrir(Widget ecran) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ecran));
    return Scaffold(
      body: ListeCharte(
        haut: Espaces.s6,
        enfants: [
          _EnTete(
            surTitre: Text(
              'Espace gérant',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            titre: 'Salon',
          ),
          const _Section('Activité'),
          CarteLien(
            titre: 'Historique',
            description: 'Prestations réalisées, absents et encaissements',
            surAppui: () => ouvrir(EcranHistorique(planning: planning)),
          ),
          const SizedBox(height: Espaces.s6),
          const _Section('Configuration'),
          CarteLien(
            titre: 'Prestations',
            description: 'Catalogue : créer, modifier, désactiver',
            surAppui: () => ouvrir(EcranPrestations(salon: salon)),
          ),
          const SizedBox(height: Espaces.s3),
          CarteLien(
            titre: 'Équipe',
            description: 'Horaires, absences et compétences de chaque coiffeur',
            surAppui: () => ouvrir(EcranEquipe(salon: salon)),
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
          _EnTete(
            surTitre: Text('Espace coiffeur', style: textes.bodySmall),
            titre: 'Salon',
          ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Espaces.s4,
                        vertical: Espaces.s1,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            if (i > 0) const Divider(),
                            _LigneHoraire(
                              jour: nomsJours[i],
                              plages: donnees.plagesDu(
                                moi,
                                lundi.add(Duration(days: i)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Espaces.s6),
                  const _Section('Mes absences (30 prochains jours)'),
                  if (absences.isEmpty)
                    Text('Aucune absence prévue.', style: textes.bodyLarge)
                  else
                    for (final a in absences) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(Espaces.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Du ${formatDateHeure(a.debut)}',
                                style: textes.bodyLarge,
                              ),
                              Text(
                                'au ${formatDateHeure(a.fin)}',
                                style: textes.bodyLarge,
                              ),
                              if (a.motif != null && a.motif!.isNotEmpty)
                                Text(a.motif!, style: textes.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Espaces.s3),
                    ],
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
class OngletProfil extends StatelessWidget {
  const OngletProfil({
    super.key,
    required this.compte,
    required this.espace,
    required this.planning,
    required this.surDeconnexion,
    this.autreEspace,
    this.surBascule,
  });

  final String compte;
  final Espace espace;
  final DepotPlanning planning;
  final Espace? autreEspace;
  final ValueChanged<Espace>? surBascule;
  final VoidCallback surDeconnexion;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final autre = autreEspace;
    final roles = autre == null
        ? (espace == Espace.gerant ? 'Gérant' : 'Coiffeur')
        : 'Gérant et coiffeur';
    return Scaffold(
      body: ListeCharte(
        haut: Espaces.s6,
        enfants: [
          // Le nom se lit en tâche de fond ; en attendant (ou sans nom),
          // l'e-mail tient lieu de nom. Tout tient à 360 × 640 : bascule et
          // déconnexion visibles sans défiler (#41).
          FutureBuilder<String?>(
            future: planning.monNom().catchError((_) => null),
            builder: (context, lecture) {
              final nom = lecture.data?.trim();
              final affiche = nom == null || nom.isEmpty ? compte : nom;
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
                    if (affiche != compte)
                      Text(compte, style: textes.bodySmall),
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
                  selected: {espace},
                  showSelectedIcon: false,
                  onSelectionChanged: (choix) => surBascule?.call(choix.first),
                ),
              ),
            ),
          ],
          const SizedBox(height: Espaces.s4),
          const _LigneProfil(
            icone: Icons.edit_outlined,
            titre: 'Modifier mes infos',
            aDroite: 'Bientôt',
          ),
          const _LigneProfil(
            icone: Icons.lock_outline,
            titre: 'Mot de passe',
            aDroite: 'Bientôt',
          ),
          const _LigneProfil(
            icone: Icons.info_outline,
            titre: 'À propos',
            aDroite: 'Version $versionApp',
          ),
          const SizedBox(height: Espaces.s3),
          Center(
            child: TextButton.icon(
              onPressed: surDeconnexion,
              style: TextButton.styleFrom(foregroundColor: Couleurs.erreur),
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
class _LigneProfil extends StatelessWidget {
  const _LigneProfil({
    required this.icone,
    required this.titre,
    required this.aDroite,
  });
  final IconData icone;
  final String titre;
  final String aDroite;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$titre, $aDroite',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Couleurs.separateur)),
        ),
        child: Row(
          children: [
            Icon(icone, color: Couleurs.texteSecondaire),
            const SizedBox(width: Espaces.s3),
            Expanded(child: Text(titre, style: textes.bodyLarge)),
            Text(aDroite, style: textes.bodySmall),
          ],
        ),
      ),
    );
  }
}
