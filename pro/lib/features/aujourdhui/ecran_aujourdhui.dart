import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../planning/cloture_differee.dart';
import '../planning/elements_planning.dart';
import 'carte_glissable.dart';

// Onglet « Accueil » (#64, refait par #72, maquette A de #66) : photo du salon
// en bandeau, « Bonjour Amira » puis le nombre de clients du jour en titre,
// rappels (à clôturer, à encaisser), rendez-vous en cours, prochain
// rendez-vous, ligne des chiffres du jour, équipe du jour (gérant), puis les
// rendez-vous du jour, à clôturer d'un geste. Peu de cadres : le vert reste
// une touche (bouton, compte à rebours), comme sur le site. Coiffeur : les
// siens ; gérant : tout le salon. Journée sans rendez-vous : « Journée calme ».
// Le total compte tous les rendez-vous du jour, en cours compris :
// terminés + absents + restants = total.
class EcranAujourdhui extends StatefulWidget {
  const EcranAujourdhui({
    super.key,
    required this.planning,
    required this.gerant,
    this.actif = true,
  });

  final DepotPlanning planning;
  final bool gerant;
  // Onglet affiché ; en le quittant, une clôture en attente part tout de suite.
  final bool actif;

  @override
  State<EcranAujourdhui> createState() => _EcranAujourdhuiState();
}

// Une seule fois par appareil, pour toujours : la première carte glissable
// montre le geste. Retenu dans les préférences de l'app ; lu au premier
// chargement, puis gardé en mémoire. Préférences illisibles : pas d'indice.
const cleIndiceGestes = 'indice_gestes_vu';
bool? _indiceVu;

Future<bool> _lireIndiceVu() async {
  try {
    return _indiceVu ??=
        (await SharedPreferences.getInstance()).getBool(cleIndiceGestes) ??
        false;
  } catch (_) {
    return _indiceVu = true;
  }
}

void _retenirIndiceVu() {
  _indiceVu = true;
  SharedPreferences.getInstance()
      .then((p) => p.setBool(cleIndiceGestes, true))
      .ignore();
}

// Tests : comme un nouveau lancement de l'app (relit les préférences).
@visibleForTesting
void reinitialiserIndice() => _indiceVu = null;

class _Jour {
  const _Jour(this.maintenant, this.nom, this.donnees, this.coiffeurs);
  final DateTime maintenant;
  final String? nom;
  final DonneesPlanning donnees;
  final Map<String, String> coiffeurs;
}

class _EcranAujourdhuiState extends State<EcranAujourdhui> {
  // Dernière lecture affichée. Les relectures (après une clôture, en tirant
  // la liste) la remplacent sans repasser par le chargement : la liste garde
  // sa position.
  _Jour? _jour;
  // Message « Annuler » de la clôture en attente.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _message;
  late final _cloture = ClotureDifferee(
    planning: widget.planning,
    surDepart: _fermerMessage,
    surEnregistree: _relire,
    surErreur: (message) {
      if (!mounted) return;
      confirmer(context, message);
      setState(() {});
    },
  );

  void _fermerMessage() {
    final message = _message;
    _message = null;
    if (message != null && mounted) message.close();
  }

  Future<void> _relire() async {
    try {
      final jour = await _lire();
      if (mounted) setState(() => _jour = jour);
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    }
  }

  @override
  void didUpdateWidget(EcranAujourdhui ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.actif && !widget.actif) _cloture.enregistrer();
  }

  @override
  void dispose() {
    _cloture.fermer();
    super.dispose();
  }

  Future<_Jour> _lire() async {
    await _lireIndiceVu();
    final maintenant = await widget.planning.maintenantAuSalon();
    final jour = DateUtils.dateOnly(maintenant);
    final resultats = await Future.wait<dynamic>([
      widget.planning.monNom(),
      widget.planning.periode(
        jour,
        jour,
        coiffeurId: widget.gerant ? null : widget.planning.moi,
      ),
      if (widget.gerant) widget.planning.coiffeurs(),
    ]);
    return _Jour(
      maintenant,
      resultats[0] as String?,
      resultats[1] as DonneesPlanning,
      {
        if (widget.gerant)
          for (final c in resultats[2] as List<Coiffeur>) c.id: c.nom,
      },
    );
  }

  // État affiché, clôture en attente comprise.
  EtatRendezVous _etat(RendezVous r, DateTime maintenant) =>
      switch (_cloture.enAttente(r.id)) {
        StatutRendezVous.terminee => EtatRendezVous.termine,
        StatutRendezVous.absent => EtatRendezVous.absent,
        _ => r.etat(maintenant),
      };

  void _geste(RendezVous r, StatutRendezVous statut) {
    setState(() => _cloture.programmer(r, statut));
    final heure = formatHeure(TimeOfDay.fromDateTime(r.debut));
    final messager = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final message = _message = messager.showSnackBar(
      SnackBar(
        duration: _cloture.delai,
        content: Text(
          statut == StatutRendezVous.terminee
              ? '${r.clientNom}, $heure : terminé.'
              : '${r.clientNom}, $heure : client absent.',
        ),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => setState(_cloture.annuler),
        ),
      ),
    );
    message.closed.then((_) {
      if (identical(_message, message)) _message = null;
    });
  }

  Future<void> _ouvrir(RendezVous r, _Jour j) async {
    await _cloture.enregistrer();
    if (!mounted) return;
    final message = await afficherRendezVous(
      context,
      r,
      planning: widget.planning,
      maintenant: j.maintenant,
      gerant: widget.gerant,
      coiffeur: j.coiffeurs[r.coiffeurId],
    );
    if (message == null || !mounted) return;
    confirmer(context, message);
    await _relire();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _relire,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaces.s4,
              Espaces.s6,
              Espaces.s4,
              Espaces.s8,
            ),
            children: [
              if (_jour case final jour?)
                _contenu(context, jour)
              else
                Chargement<_Jour>(
                  lire: () async => _jour = await _lire(),
                  afficher: (context, j, _) => _contenu(context, j),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenu(BuildContext context, _Jour j) {
    final textes = Theme.of(context).textTheme;
    final jour = DateUtils.dateOnly(j.maintenant);
    final rdv = [
      for (final r in j.donnees.rendezVous)
        if (memeJour(r.debut, jour)) r,
    ]..sort((a, b) => a.debut.compareTo(b.debut));
    final etats = {for (final r in rdv) r.id: _etat(r, j.maintenant)};
    int compte(EtatRendezVous e) => etats.values.where((x) => x == e).length;
    final termines = compte(EtatRendezVous.termine);
    final absents = compte(EtatRendezVous.absent);
    final restants = rdv.length - termines - absents;
    final aCloturer = compte(EtatRendezVous.aCloturer);
    final aEncaisser = widget.gerant
        ? rdv
              .where(
                (r) =>
                    r.statut == StatutRendezVous.terminee &&
                    r.montantEncaisse == null,
              )
              .length
        : 0;
    final enCours = [
      for (final r in rdv)
        if (etats[r.id] == EtatRendezVous.enCours) r,
    ];
    final prochain = rdv
        .where((r) => etats[r.id] == EtatRendezVous.aVenir)
        .firstOrNull;
    final prenom = _prenom(j.nom);
    final titre = switch (rdv.length) {
      0 => 'Journée calme aujourd\'hui',
      1 => '1 client aujourd\'hui',
      final n => '$n clients aujourd\'hui',
    };
    final premierGlissable = rdv
        .where(
          (r) => r.cloturable(j.maintenant) && _cloture.enAttente(r.id) == null,
        )
        .firstOrNull;
    final indice = _indiceVu == false && premierGlissable != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BandeauSalon(),
        const SizedBox(height: Espaces.s4),
        Text(
          '${formatDate(jour)} · ${widget.gerant ? 'Espace gérant' : 'Espace coiffeur'}',
          style: textes.bodySmall,
        ),
        Text(
          prenom == null ? 'Bonjour' : 'Bonjour $prenom',
          style: textes.bodyLarge,
        ),
        Semantics(
          header: true,
          child: Text(
            titre,
            style: textes.headlineMedium!.copyWith(height: 1.2),
          ),
        ),
        if (aCloturer > 0) ...[
          const SizedBox(height: Espaces.s3),
          _Rappel(
            texte: aCloturer == 1
                ? '1 rendez-vous à clôturer'
                : '$aCloturer rendez-vous à clôturer',
            icone: Icons.pending_actions_outlined,
          ),
        ],
        if (aEncaisser > 0) ...[
          const SizedBox(height: Espaces.s2),
          _Rappel(
            texte: aEncaisser == 1
                ? '1 rendez-vous à encaisser'
                : '$aEncaisser rendez-vous à encaisser',
            icone: Icons.payments_outlined,
          ),
        ],
        const SizedBox(height: Espaces.s6),
        for (final r in enCours) ...[
          _BandeauEnCours(
            rendezVous: r,
            coiffeur: j.coiffeurs[r.coiffeurId],
            surAppui: () => _ouvrir(r, j),
          ),
          const SizedBox(height: Espaces.s3),
        ],
        if (rdv.isEmpty)
          const _JourneeCalme()
        else ...[
          if (prochain != null)
            _Prochain(
              rendezVous: prochain,
              maintenant: j.maintenant,
              coiffeur: j.coiffeurs[prochain.coiffeurId],
              gerant: widget.gerant,
              surAppui: () => _ouvrir(prochain, j),
            )
          else
            Text(
              'Plus de rendez-vous à venir aujourd\'hui.',
              style: textes.bodyLarge,
            ),
          const SizedBox(height: Espaces.s6),
          _Chiffres(
            restants: restants,
            termines: termines,
            absents: absents,
            encaisse: widget.gerant
                ? rdv.fold<double>(
                    0,
                    (somme, r) => somme + (r.montantEncaisse ?? 0),
                  )
                : null,
          ),
        ],
        if (widget.gerant && rdv.isNotEmpty && j.coiffeurs.isNotEmpty) ...[
          const SizedBox(height: Espaces.s6),
          _Equipe(coiffeurs: j.coiffeurs, rendezVous: rdv),
        ],
        if (rdv.isNotEmpty) ...[
          const SizedBox(height: Espaces.s6),
          Semantics(
            header: true,
            child: Text('Rendez-vous du jour', style: textes.titleMedium),
          ),
          const SizedBox(height: Espaces.s1),
          Text(
            'Une fois commencé, glissez à droite : terminé ; '
            'à gauche : client absent.',
            style: textes.bodySmall,
          ),
          const SizedBox(height: Espaces.s3),
          for (final r in rdv) ...[
            CarteGlissable(
              rendezVous: r,
              etat: etats[r.id]!,
              glissable:
                  r.cloturable(j.maintenant) &&
                  _cloture.enAttente(r.id) == null,
              coiffeur: j.coiffeurs[r.coiffeurId],
              indice: indice && r.id == premierGlissable.id,
              surIndiceMontre: _retenirIndiceVu,
              surAppui: () => _ouvrir(r, j),
              surGeste: (statut) => _geste(r, statut),
            ),
            const SizedBox(height: Espaces.s2),
          ],
        ],
      ],
    );
  }
}

// Premier mot du nom : « Amira Ben Salah » → « Amira ». Sans nom : null.
String? _prenom(String? nom) {
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

class _BandeauEnCours extends StatelessWidget {
  const _BandeauEnCours({
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
        color: Couleurs.accent,
        borderRadius: BorderRadius.circular(rayon),
        child: InkWell(
          onTap: surAppui,
          borderRadius: BorderRadius.circular(rayon),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: hauteurBouton),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Espaces.s3,
                vertical: Espaces.s2,
              ),
              child: Row(
                children: [
                  Text(
                    'En cours',
                    style: textes.labelLarge!.copyWith(color: Couleurs.surface),
                  ),
                  const SizedBox(width: Espaces.s3),
                  Expanded(
                    child: Text(
                      texte,
                      style: textes.bodyMedium!.copyWith(
                        color: Couleurs.surface,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Couleurs.surface),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Photo du salon en bandeau, sans texte dessus (comme sur le site, charte
// §6). Image par défaut tant que le salon ne peut pas envoyer la sienne (#74).
class _BandeauSalon extends StatelessWidget {
  const _BandeauSalon();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: Image.asset(
        'assets/images/salon-defaut.webp',
        height: 104,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.2),
        semanticLabel: 'Photo du salon',
      ),
    );
  }
}

// Rappel en tête (à clôturer, à encaisser) : fond ambre pâle, comme l'état
// « À clôturer ».
class _Rappel extends StatelessWidget {
  const _Rappel({required this.texte, required this.icone});
  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.s3,
        vertical: Espaces.s2,
      ),
      decoration: BoxDecoration(
        color: CouleursStatut.aCloturerFond,
        borderRadius: BorderRadius.circular(rayon),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icone, color: CouleursStatut.aCloturerTexte),
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
        ],
      ),
    );
  }
}

// Journée sans rendez-vous : un message plutôt qu'une rangée de zéros.
class _JourneeCalme extends StatelessWidget {
  const _JourneeCalme();

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
            child: const Icon(
              Icons.local_cafe_outlined,
              color: Couleurs.texteSecondaire,
            ),
          ),
        ),
        const SizedBox(width: Espaces.s4),
        Expanded(
          child: Text(
            'Aucun rendez-vous prévu pour l\'instant.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// Prochain rendez-vous, sans cadre : client (avatar), prestation et coiffeur,
// heure en grand et compte à rebours sur une seule ligne, bouton principal.
class _Prochain extends StatelessWidget {
  const _Prochain({
    required this.rendezVous,
    required this.maintenant,
    required this.gerant,
    required this.surAppui,
    this.coiffeur,
  });
  final RendezVous rendezVous;
  final DateTime maintenant;
  final bool gerant;
  final String? coiffeur;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final r = rendezVous;
    final details = [r.prestation, if (coiffeur != null) 'avec $coiffeur'];
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
            Avatar(nom: r.clientNom),
            const SizedBox(width: Espaces.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.clientNom, style: textes.titleSmall),
                  Text(details.join(' · '), style: textes.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Espaces.s3),
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
        Align(
          alignment: Alignment.centerLeft,
          child: Bouton(libelle: 'Ouvrir la fiche', surAppui: surAppui),
        ),
      ],
    );
  }
}

// Chiffres du jour, sans cadre, entre deux filets : restants, terminé, absent,
// puis encaissé (gérant).
class _Chiffres extends StatelessWidget {
  const _Chiffres({
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
              child: _Chiffre(
                icone: Icons.schedule,
                valeur: '$restants',
                libelle: accord(restants, 'restant'),
              ),
            ),
            Expanded(
              child: _Chiffre(
                icone: Icons.check,
                valeur: '$termines',
                libelle: accord(termines, 'terminé'),
              ),
            ),
            Expanded(
              child: _Chiffre(
                icone: Icons.person_off_outlined,
                valeur: '$absents',
                libelle: accord(absents, 'absent'),
              ),
            ),
            if (total != null)
              Expanded(
                child: _Chiffre(
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

class _Chiffre extends StatelessWidget {
  const _Chiffre({
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
class _Equipe extends StatelessWidget {
  const _Equipe({required this.coiffeurs, required this.rendezVous});
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
                  child: _MembreEquipe(
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

class _MembreEquipe extends StatelessWidget {
  const _MembreEquipe({required this.nom, required this.nombre});
  final String nom;
  final int nombre;

  @override
  Widget build(BuildContext context) {
    final prenom = _prenom(nom) ?? nom;
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
