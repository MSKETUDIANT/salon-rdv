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

// Onglet « Aujourd'hui » (#64) : titre éditorial (« Bonjour Amira, 6 clients
// aujourd'hui »), rendez-vous en cours, grande carte du prochain rendez-vous,
// chiffres du jour (encaissé pour le gérant), puis les rendez-vous du jour,
// à clôturer d'un geste. Coiffeur : les siens ; gérant : tout le salon.
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
    final enCours = [
      for (final r in rdv)
        if (etats[r.id] == EtatRendezVous.enCours) r,
    ];
    final prochain = rdv
        .where((r) => etats[r.id] == EtatRendezVous.aVenir)
        .firstOrNull;
    final prenom = j.nom?.trim().split(RegExp(r'\s+')).first;
    final clients = switch (rdv.length) {
      0 => 'aucun client aujourd\'hui',
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
        Text(
          '${formatDate(jour)} · ${widget.gerant ? 'Espace gérant' : 'Espace coiffeur'}',
          style: textes.bodySmall,
        ),
        const SizedBox(height: Espaces.s1),
        Semantics(
          header: true,
          child: Text(
            prenom == null || prenom.isEmpty
                ? 'Bonjour,\n$clients'
                : 'Bonjour $prenom,\n$clients',
            style: textes.displaySmall!.copyWith(height: 1.15),
          ),
        ),
        const SizedBox(height: Espaces.s4),
        for (final r in enCours) ...[
          _BandeauEnCours(
            rendezVous: r,
            coiffeur: j.coiffeurs[r.coiffeurId],
            surAppui: () => _ouvrir(r, j),
          ),
          const SizedBox(height: Espaces.s3),
        ],
        if (prochain != null)
          _CarteProchain(
            rendezVous: prochain,
            maintenant: j.maintenant,
            coiffeur: j.coiffeurs[prochain.coiffeurId],
            gerant: widget.gerant,
            surAppui: () => _ouvrir(prochain, j),
          )
        else
          Text(
            rdv.isEmpty
                ? 'Aucun rendez-vous aujourd\'hui.'
                : 'Plus de rendez-vous à venir aujourd\'hui.',
            style: textes.bodyLarge,
          ),
        const SizedBox(height: Espaces.s4),
        if (widget.gerant) ...[
          _Encaisse(rendezVous: rdv),
          const SizedBox(height: Espaces.s2),
        ],
        Semantics(
          container: true,
          label: 'Chiffres du jour',
          child: Row(
            children: [
              Expanded(
                child: _Chiffre(
                  nombre: termines,
                  libelle: termines > 1 ? 'terminés' : 'terminé',
                ),
              ),
              const SizedBox(width: Espaces.s2),
              Expanded(
                child: _Chiffre(
                  nombre: absents,
                  libelle: absents > 1 ? 'absents' : 'absent',
                ),
              ),
              const SizedBox(width: Espaces.s2),
              Expanded(
                child: _Chiffre(
                  nombre: restants,
                  libelle: restants > 1 ? 'restants' : 'restant',
                ),
              ),
            ],
          ),
        ),
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

class _CarteProchain extends StatelessWidget {
  const _CarteProchain({
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
    final details = [
      if (coiffeur != null) 'avec $coiffeur',
      formatDuree(r.dureeMinutes),
      formatPrix(r.prix),
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaces.s4,
          Espaces.s4,
          Espaces.s4,
          Espaces.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              gerant ? 'Prochain rendez-vous du salon' : 'Prochain rendez-vous',
              style: textes.bodySmall,
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: Espaces.s3,
              children: [
                Text(
                  formatHeure(TimeOfDay.fromDateTime(r.debut)),
                  style: textes.displaySmall!.copyWith(
                    fontSize: 44,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: Espaces.s1),
                  child: Text(
                    _dans(r.debut.difference(maintenant)),
                    style: textes.labelLarge!.copyWith(color: Couleurs.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaces.s2),
            Text(r.clientNom, style: textes.titleMedium),
            Text('${r.prestation} · $details', style: textes.bodySmall),
            const SizedBox(height: Espaces.s3),
            Bouton(
              libelle: 'Ouvrir la fiche',
              secondaire: true,
              pleineLargeur: true,
              surAppui: surAppui,
            ),
          ],
        ),
      ),
    );
  }
}

// Gérant : encaissé aujourd'hui (montants enregistrés des rendez-vous du
// jour), et ce qui reste à encaisser.
class _Encaisse extends StatelessWidget {
  const _Encaisse({required this.rendezVous});
  final List<RendezVous> rendezVous;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final total = rendezVous.fold<double>(
      0,
      (somme, r) => somme + (r.montantEncaisse ?? 0),
    );
    final aEncaisser = rendezVous
        .where(
          (r) =>
              r.statut == StatutRendezVous.terminee &&
              r.montantEncaisse == null,
        )
        .length;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaces.s4,
          vertical: Espaces.s3,
        ),
        decoration: BoxDecoration(
          color: Couleurs.accent,
          borderRadius: BorderRadius.circular(rayon),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encaissé aujourd\'hui',
                    style: textes.bodyMedium!.copyWith(color: Couleurs.surface),
                  ),
                  if (aEncaisser > 0)
                    Text(
                      aEncaisser == 1
                          ? '1 à encaisser'
                          : '$aEncaisser à encaisser',
                      style: textes.bodyMedium!.copyWith(
                        color: Couleurs.surface,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatPrix(total),
              style: textes.headlineMedium!.copyWith(
                color: Couleurs.surface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.nombre, required this.libelle});
  final int nombre;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$nombre $libelle',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.s3,
            vertical: Espaces.s2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$nombre', style: textes.headlineMedium),
              Text(libelle, style: textes.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
