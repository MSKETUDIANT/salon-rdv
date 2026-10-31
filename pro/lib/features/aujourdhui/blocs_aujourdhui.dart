import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../../ui/photo_salon.dart';

// Blocs de l'onglet « Accueil » (ecran_aujourdhui.dart) : bandeaux, rappel,
// prochain rendez-vous, chiffres du jour, équipe du jour.

// Premier mot du nom : « Amira Ben Salah » → « Amira ». Sans nom : null.
String? prenomDe(String? nom) {
  final premier = nom?.trim().split(RegExp(r'\s+')).first;
  return premier == null || premier.isEmpty ? null : premier;
}

String _dans(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return 'maintenant';
  if (minutes < 60) return 'dans $minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? 'dans $h h' : 'dans $h h ${m.toString().padLeft(2, '0')}';
}

class BandeauEnCours extends StatelessWidget {
  const BandeauEnCours({
    super.key,
    required this.rendezVous,
    required this.surAppui,
    this.coiffeur,
  });
  final RendezVous rendezVous;
  final String? coiffeur;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = rendezVous;
    final heures =
        '${formatHeure(TimeOfDay.fromDateTime(r.debut))} – ${formatHeure(TimeOfDay.fromDateTime(r.fin))}';
    final texte = [
      heures,
      '${r.clientNom}, ${r.prestation}',
      ?coiffeur,
    ].join(' · ');
    return Semantics(
      container: true,
      button: true,
      label: 'En cours : $texte',
      onTap: surAppui,
      excludeSemantics: true,
      child: Material(
        color: Couleurs.fond,
        child: InkWell(
          onTap: surAppui,
          borderRadius: BorderRadius.circular(rayon),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: hauteurBouton),
            child: Row(
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.schedule, color: Couleurs.accent),
                ),
                const SizedBox(width: Espaces.s2),
                Text(
                  'En cours',
                  style: textes.labelLarge!.copyWith(color: Couleurs.accent),
                ),
                const SizedBox(width: Espaces.s3),
                Expanded(child: Text(texte, style: textes.bodyMedium)),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: Couleurs.texteSecondaire,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Photo du salon en bandeau, sans texte dessus (comme sur le site, charte
// §6) : celle envoyée par le gérant (#105), sinon l'image par défaut.
class BandeauSalon extends StatelessWidget {
  const BandeauSalon({super.key, this.photo});
  // Photo envoyée par le gérant (#105), null : image par défaut.
  final String? photo;

  @override
  Widget build(BuildContext context) =>
      PhotoSalon(adresse: photo, hauteur: 104);
}

// Rappel en tête, une seule ligne (« 1 à clôturer · 1 à encaisser ») : fond
// ambre pâle, comme l'état « À clôturer ». S'il y a des rendez-vous à
// clôturer, un appui fait défiler jusqu'au premier dans la liste (#72).
class Rappel extends StatelessWidget {
  const Rappel({super.key, required this.texte, this.surAppui});
  final String texte;
  final VoidCallback? surAppui;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: surAppui != null,
      child: Material(
        color: CouleursStatut.aCloturerFond,
        borderRadius: BorderRadius.circular(rayon),
        child: InkWell(
          onTap: surAppui,
          borderRadius: BorderRadius.circular(rayon),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaces.s3,
              vertical: Espaces.s2,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.pending_actions_outlined,
                    color: CouleursStatut.aCloturerTexte,
                  ),
                ),
                const SizedBox(width: Espaces.s2),
                Expanded(
                  child: Text(
                    texte,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: CouleursStatut.aCloturerTexte,
                    ),
                  ),
                ),
                if (surAppui != null)
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: CouleursStatut.aCloturerTexte,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Message du jour, icône dans un rond : journée sans rendez-vous (pas de
// rangée de zéros), ou plus rien à venir (#72).
class MessageJour extends StatelessWidget {
  const MessageJour({super.key, required this.icone, required this.texte});
  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Couleurs.separateur,
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: Couleurs.texteSecondaire),
          ),
        ),
        const SizedBox(width: Espaces.s4),
        Expanded(
          child: Text(texte, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

// Prochain rendez-vous, sans cadre : client (avatar), prestation et coiffeur,
// heure en grand et compte à rebours sur une seule ligne, bouton principal.
class Prochain extends StatelessWidget {
  const Prochain({
    super.key,
    required this.rendezVous,
    required this.maintenant,
    required this.gerant,
    required this.surAppui,
    required this.surArrivee,
    this.arriveeEnCours = false,
    this.coiffeur,
  });
  final RendezVous rendezVous;
  final DateTime maintenant;
  final bool gerant;
  final String? coiffeur;
  final VoidCallback surAppui;
  // Client arrivé (#102, option 2a) : en un geste, là où l'on regarde quand
  // le client entre. Une fois arrivé : l'heure, et l'annulation dans la fiche.
  final VoidCallback surArrivee;
  final bool arriveeEnCours;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = rendezVous;
    final details = [r.prestation, ?coiffeur];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          gerant ? 'Prochain rendez-vous du salon' : 'Prochain rendez-vous',
          style: textes.bodySmall,
        ),
        const SizedBox(height: Espaces.s2),
        Row(
          children: [
            Avatar(nom: r.clientNom, taille: 40),
            const SizedBox(width: Espaces.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.clientNom, style: textes.titleSmall),
                  Text(
                    details.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textes.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Espaces.s2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatHeure(TimeOfDay.fromDateTime(r.debut)),
                  style: textes.displaySmall!.copyWith(
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _dans(r.debut.difference(maintenant)),
                  maxLines: 1,
                  softWrap: false,
                  style: textes.labelLarge!.copyWith(color: Couleurs.accent),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: Espaces.s3),
        if (r.arriveLe case final a?) ...[
          Row(
            children: [
              const ExcludeSemantics(
                child: Icon(
                  Icons.how_to_reg_outlined,
                  size: 20,
                  color: Couleurs.accent,
                ),
              ),
              const SizedBox(width: Espaces.s1),
              Text(
                'Arrivé à ${formatHeure(TimeOfDay.fromDateTime(a))}',
                style: textes.labelLarge!.copyWith(color: Couleurs.accent),
              ),
            ],
          ),
          const SizedBox(height: Espaces.s3),
        ],
        // Retour à la ligne si la police du téléphone est grande (#83).
        Wrap(
          spacing: Espaces.s2,
          runSpacing: Espaces.s2,
          children: [
            if (r.arriveLe == null)
              Bouton(
                libelle: 'Client arrivé',
                libelleChargement: 'Enregistrement…',
                chargement: arriveeEnCours,
                surAppui: surArrivee,
              ),
            Bouton(
              libelle: 'Ouvrir la fiche',
              secondaire: r.arriveLe == null,
              surAppui: surAppui,
            ),
          ],
        ),
      ],
    );
  }
}

// Chiffres du jour, sans cadre, entre deux filets : restants, terminé, absent,
// puis encaissé (gérant).
class Chiffres extends StatelessWidget {
  const Chiffres({
    super.key,
    required this.restants,
    required this.termines,
    required this.absents,
    this.encaisse,
  });
  final int restants;
  final int termines;
  final int absents;
  final double? encaisse;

  @override
  Widget build(BuildContext context) {
    String accord(int n, String mot) => n > 1 ? '${mot}s' : mot;
    final total = encaisse;
    return Semantics(
      container: true,
      label: 'Chiffres du jour',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Espaces.s3),
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: Couleurs.separateur),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Chiffre(
                icone: Icons.schedule,
                valeur: '$restants',
                libelle: accord(restants, 'restant'),
              ),
            ),
            Expanded(
              child: Chiffre(
                icone: Icons.check,
                valeur: '$termines',
                libelle: accord(termines, 'terminé'),
              ),
            ),
            Expanded(
              child: Chiffre(
                icone: Icons.person_off_outlined,
                valeur: '$absents',
                libelle: accord(absents, 'absent'),
              ),
            ),
            if (total != null)
              Expanded(
                child: Chiffre(
                  icone: Icons.payments_outlined,
                  valeur: formatPrix(total),
                  libelle: 'encaissé',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class Chiffre extends StatelessWidget {
  const Chiffre({
    super.key,
    required this.icone,
    required this.valeur,
    required this.libelle,
  });
  final IconData icone;
  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$valeur $libelle',
      excludeSemantics: true,
      child: Column(
        children: [
          Icon(icone, color: Couleurs.texteSecondaire),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valeur,
              style: textes.headlineSmall!.copyWith(
                height: 1.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(libelle, style: textes.bodySmall),
        ],
      ),
    );
  }
}

// Équipe du jour (gérant) : une ligne d'avatars ronds, prénom et nombre de
// rendez-vous du jour ; défile si l'équipe ne tient pas sur la largeur.
class Equipe extends StatelessWidget {
  const Equipe({super.key, required this.coiffeurs, required this.rendezVous});
  final Map<String, String> coiffeurs;
  final List<RendezVous> rendezVous;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'L\'équipe aujourd\'hui',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: Espaces.s2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final MapEntry(key: id, value: nom) in coiffeurs.entries)
                Padding(
                  padding: const EdgeInsets.only(right: Espaces.s4),
                  child: MembreEquipe(
                    nom: nom,
                    nombre: rendezVous.where((r) => r.coiffeurId == id).length,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class MembreEquipe extends StatelessWidget {
  const MembreEquipe({super.key, required this.nom, required this.nombre});
  final String nom;
  final int nombre;

  @override
  Widget build(BuildContext context) {
    final prenom = prenomDe(nom) ?? nom;
    return Semantics(
      container: true,
      label: '$prenom, $nombre rendez-vous',
      excludeSemantics: true,
      child: Column(
        children: [
          Avatar(nom: nom, taille: 44),
          const SizedBox(height: Espaces.s1),
          Text(
            '$prenom · $nombre',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
