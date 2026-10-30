import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/format.dart';
import '../planning/cloture_differee.dart';
import '../planning/elements_planning.dart';
import 'blocs_aujourdhui.dart';
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
  // Premier rendez-vous à clôturer de la liste : le rappel y fait défiler.
  final _premierACloturer = GlobalKey();
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
    // Retour sur l'onglet : relu sans repasser par le chargement (le nom a pu
    // changer dans le profil, #106).
    if (!ancien.actif && widget.actif && _jour != null) _relire();
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

  // Rendez-vous dont l'arrivée s'enregistre (bouton en attente).
  String? _arriveeEnCours;

  // Client arrivé depuis la carte du prochain rendez-vous (#102).
  Future<void> _arrivee(RendezVous r) async {
    setState(() => _arriveeEnCours = r.id);
    try {
      await widget.planning.marquerArrivee(r.id);
      if (!mounted) return;
      confirmer(context, 'Arrivée de ${r.clientNom} notée.');
      await _relire();
    } on ErreurSalon catch (erreur) {
      if (mounted) confirmer(context, erreur.message);
    } finally {
      if (mounted) setState(() => _arriveeEnCours = null);
    }
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
    // Restants (#72) : à venir (arrivés compris, #102) et en cours seulement ;
    // les rendez-vous passés à clôturer sont dans le rappel, pas dans ce
    // chiffre.
    final restants =
        compte(EtatRendezVous.aVenir) +
        compte(EtatRendezVous.arrive) +
        compte(EtatRendezVous.enCours);
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
        .where(
          (r) =>
              etats[r.id] == EtatRendezVous.aVenir ||
              etats[r.id] == EtatRendezVous.arrive,
        )
        .firstOrNull;
    final prenom = prenomDe(j.nom);
    final titre = switch (rdv.length) {
      0 => 'Journée calme aujourd\'hui',
      1 => '1 client aujourd\'hui',
      final n => '$n clients aujourd\'hui',
    };
    final premierACloturer = rdv
        .where((r) => etats[r.id] == EtatRendezVous.aCloturer)
        .firstOrNull;
    final premierGlissable = rdv
        .where(
          (r) => r.cloturable(j.maintenant) && _cloture.enAttente(r.id) == null,
        )
        .firstOrNull;
    final indice = _indiceVu == false && premierGlissable != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BandeauSalon(),
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
        if (aCloturer > 0 || aEncaisser > 0) ...[
          const SizedBox(height: Espaces.s3),
          Rappel(
            texte: [
              if (aCloturer > 0) '$aCloturer à clôturer',
              if (aEncaisser > 0) '$aEncaisser à encaisser',
            ].join(' · '),
            surAppui: aCloturer == 0
                ? null
                : () {
                    final cible = _premierACloturer.currentContext;
                    if (cible != null) {
                      Scrollable.ensureVisible(
                        cible,
                        duration: const Duration(milliseconds: 300),
                        alignment: 0.1,
                      );
                    }
                  },
          ),
        ],
        const SizedBox(height: Espaces.s6),
        for (final r in enCours) ...[
          BandeauEnCours(
            rendezVous: r,
            coiffeur: j.coiffeurs[r.coiffeurId],
            surAppui: () => _ouvrir(r, j),
          ),
          const SizedBox(height: Espaces.s3),
        ],
        if (rdv.isEmpty)
          const MessageJour(
            icone: Icons.local_cafe_outlined,
            texte: 'Aucun rendez-vous prévu pour l\'instant.',
          )
        else ...[
          if (prochain != null)
            Prochain(
              rendezVous: prochain,
              maintenant: j.maintenant,
              coiffeur: j.coiffeurs[prochain.coiffeurId],
              gerant: widget.gerant,
              surAppui: () => _ouvrir(prochain, j),
              surArrivee: () => _arrivee(prochain),
              arriveeEnCours: _arriveeEnCours == prochain.id,
            )
          else
            const MessageJour(
              icone: Icons.done_all,
              texte: 'Plus de rendez-vous à venir aujourd\'hui.',
            ),
          const SizedBox(height: Espaces.s6),
          Chiffres(
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
          Equipe(coiffeurs: j.coiffeurs, rendezVous: rdv),
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
              key: r.id == premierACloturer?.id ? _premierACloturer : null,
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
          ],
        ],
      ],
    );
  }
}
