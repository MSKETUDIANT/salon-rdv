import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import '../planning/formulaire_encaissement.dart';

// Historique du salon pour le gérant (#11, BF-K3, BF-G4) : prestations
// réalisées, clients absents et encaissements, filtrés par période et par
// coiffeur. Refait par #82 : sans cadre, total en grand, « à encaisser » en
// filtre, une ligne par prestation ; encaissement depuis la ligne, correction
// du montant en touchant une ligne payée.
class EcranHistorique extends StatefulWidget {
  const EcranHistorique({super.key, required this.planning});
  final DepotPlanning planning;

  @override
  State<EcranHistorique> createState() => _EcranHistoriqueState();
}

enum _Periode {
  // Libellés courts : une ligne chacun à 360 px.
  semaine('Semaine'),
  mois('Mois'),
  moisPrecedent('Mois dernier');

  const _Periode(this.libelle);
  final String libelle;
}

class _Donnees {
  const _Donnees(this.du, this.au, this.coiffeurs, this.lignes);
  final DateTime du;
  final DateTime au;
  final List<Coiffeur> coiffeurs;
  final List<LigneHistorique> lignes;
}

class _EcranHistoriqueState extends State<EcranHistorique> {
  _Periode _periode = _Periode.semaine;
  // null : tous les coiffeurs.
  String? _coiffeur;
  int _version = 0;
  // « N à encaisser » touché : la liste ne montre que ceux-là (#82).
  bool _seulementAEncaisser = false;

  // Bornes de la période, à l'heure du salon : 31 jours au plus.
  (DateTime, DateTime) _bornes(DateTime aujourdhui) {
    switch (_periode) {
      case _Periode.semaine:
        final lundi = lundiDe(aujourdhui);
        return (lundi, lundi.add(const Duration(days: 6)));
      case _Periode.mois:
        return (
          DateTime(aujourdhui.year, aujourdhui.month, 1),
          DateTime(aujourdhui.year, aujourdhui.month + 1, 0),
        );
      case _Periode.moisPrecedent:
        return (
          DateTime(aujourdhui.year, aujourdhui.month - 1, 1),
          DateTime(aujourdhui.year, aujourdhui.month, 0),
        );
    }
  }

  Future<_Donnees> _lire() async {
    final aujourdhui = DateUtils.dateOnly(
      await widget.planning.maintenantAuSalon(),
    );
    final (du, au) = _bornes(aujourdhui);
    final resultats = await Future.wait<dynamic>([
      widget.planning.coiffeurs(),
      widget.planning.historique(du, au, coiffeurId: _coiffeur),
    ]);
    return _Donnees(
      du,
      au,
      resultats[0] as List<Coiffeur>,
      resultats[1] as List<LigneHistorique>,
    );
  }

  void _relire() => setState(() => _version++);

  Future<void> _encaisser(LigneHistorique l) async {
    final correction = l.montant != null;
    final enregistre = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormulaireEncaissement(
          planning: widget.planning,
          rendezVousId: l.id,
          resume:
              '${formatDateHeure(l.debut)} · ${l.clientNom} · ${l.prestation}',
          prix: l.prix,
          montantActuel: l.montant,
        ),
      ),
    );
    if (enregistre != true || !mounted) return;
    confirmer(
      context,
      correction ? 'Montant corrigé.' : 'Encaissement enregistré.',
    );
    _relire();
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Historique')),
      // Tirer vers le bas pour actualiser (#82, comme le planning).
      body: RefreshIndicator(
        onRefresh: () async => _relire(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            Espaces.s4,
            0,
            Espaces.s4,
            Espaces.s8,
          ),
          children: [
            // Période : pastilles sans cadre, choisie en vert sur gris clair.
            Wrap(
              spacing: Espaces.s2,
              children: [
                for (final p in _Periode.values)
                  _Pastille(
                    libelle: p.libelle,
                    choisie: p == _periode,
                    surChoix: () => setState(() {
                      _periode = p;
                      _seulementAEncaisser = false;
                      _version++;
                    }),
                  ),
              ],
            ),
            Chargement<_Donnees>(
              key: ValueKey('$_version-$_periode-$_coiffeur'),
              lire: _lire,
              afficher: (context, d, _) {
                final aEncaisser = d.lignes.where((l) => l.aEncaisser).length;
                final filtre = _seulementAEncaisser && aEncaisser > 0;
                final lignes = filtre
                    ? [
                        for (final l in d.lignes)
                          if (l.aEncaisser) l,
                      ]
                    : d.lignes;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Espaces.s2),
                    // Coiffeur : « Tous » puis prénom et petit avatar.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Pastille(
                            libelle: 'Tous',
                            choisie: _coiffeur == null,
                            surChoix: () => _choisirCoiffeur(null),
                          ),
                          for (final c in d.coiffeurs) ...[
                            const SizedBox(width: Espaces.s2),
                            _Pastille(
                              libelle: _prenom(c.nom),
                              avatar: c.nom,
                              choisie: _coiffeur == c.id,
                              surChoix: () => _choisirCoiffeur(c.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Espaces.s4),
                    _Totaux(
                      du: d.du,
                      au: d.au,
                      lignes: d.lignes,
                      aEncaisser: aEncaisser,
                      filtre: filtre,
                      surFiltre: () => setState(
                        () => _seulementAEncaisser = !_seulementAEncaisser,
                      ),
                    ),
                    const SizedBox(height: Espaces.s4),
                    if (lignes.isEmpty)
                      Text(
                        'Aucune prestation réalisée ni absence sur cette période.',
                        style: textes.bodyLarge,
                      )
                    else
                      _ListeParJour(lignes: lignes, surEncaisser: _encaisser),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _choisirCoiffeur(String? id) {
    if (id == _coiffeur) return;
    setState(() {
      _coiffeur = id;
      _seulementAEncaisser = false;
      _version++;
    });
  }
}

// Premier mot du nom : « Patron Démo » → « Patron ».
String _prenom(String nom) => nom.trim().split(RegExp(r'\s+')).first;

// Pastille de choix sans cadre (comme les onglets du planning, #79) : choisie
// en vert sur gris clair, les autres en gris ; avatar facultatif.
class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.libelle,
    required this.choisie,
    required this.surChoix,
    this.avatar,
  });
  final String libelle;
  final bool choisie;
  final VoidCallback surChoix;
  final String? avatar;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: avatar == null ? null : Avatar(nom: avatar!, taille: 24),
      label: Text(libelle),
      labelStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
        color: choisie ? Couleurs.accent : Couleurs.texteSecondaire,
      ),
      selectedColor: Couleurs.separateur,
      backgroundColor: Couleurs.fond,
      side: BorderSide.none,
      showCheckmark: false,
      selected: choisie,
      onSelected: (_) => surChoix(),
    );
  }
}

// Total encaissé en très grand sur le fond ; « N à encaisser » en action : un
// toucher ne montre que les rendez-vous à encaisser, un autre montre tout (#82,
// option 2A).
class _Totaux extends StatelessWidget {
  const _Totaux({
    required this.du,
    required this.au,
    required this.lignes,
    required this.aEncaisser,
    required this.filtre,
    required this.surFiltre,
  });
  final DateTime du;
  final DateTime au;
  final List<LigneHistorique> lignes;
  final int aEncaisser;
  final bool filtre;
  final VoidCallback surFiltre;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final realisees = lignes
        .where((l) => l.statut == StatutRendezVous.terminee)
        .length;
    final absents = lignes.length - realisees;
    final total = lignes.fold<double>(0, (s, l) => s + (l.montant ?? 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            'Du ${formatDate(du).toLowerCase()} au ${formatDate(au).toLowerCase()}',
            style: textes.bodySmall,
          ),
        ),
        const SizedBox(height: Espaces.s2),
        Semantics(
          container: true,
          label: 'Total encaissé : ${formatPrix(total)}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Encaissé', style: textes.bodySmall),
              Text(
                formatPrix(total),
                style: textes.displaySmall!.copyWith(
                  fontSize: 44,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Espaces.s1),
        Text(
          '$realisees prestation${realisees > 1 ? 's' : ''} réalisée${realisees > 1 ? 's' : ''}'
          ' · $absents absent${absents > 1 ? 's' : ''}',
          style: textes.bodySmall,
        ),
        if (aEncaisser > 0) ...[
          const SizedBox(height: Espaces.s3),
          Semantics(
            button: true,
            toggled: filtre,
            child: Material(
              color: CouleursStatut.aCloturerFond,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: surFiltre,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Espaces.s4,
                    vertical: Espaces.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          filtre ? Icons.close : Icons.filter_list,
                          color: CouleursStatut.aCloturerTexte,
                        ),
                      ),
                      const SizedBox(width: Espaces.s2),
                      Text(
                        filtre ? 'Tout voir' : '$aEncaisser à encaisser',
                        style: textes.labelLarge!.copyWith(
                          color: CouleursStatut.aCloturerTexte,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ListeParJour extends StatelessWidget {
  const _ListeParJour({required this.lignes, required this.surEncaisser});
  final List<LigneHistorique> lignes;
  final ValueChanged<LigneHistorique> surEncaisser;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final enfants = <Widget>[];
    DateTime? jour;
    for (final l in lignes) {
      final j = DateUtils.dateOnly(l.debut);
      if (jour == null || j != jour) {
        jour = j;
        enfants.addAll([
          if (enfants.isNotEmpty) const SizedBox(height: Espaces.s4),
          Semantics(
            header: true,
            child: Text(formatDate(j), style: textes.labelSmall),
          ),
        ]);
      }
      enfants.add(_Ligne(ligne: l, surEncaisser: () => surEncaisser(l)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: enfants,
    );
  }
}

// Une ligne par prestation, sans cadre (#82) : coiffeur en petit avatar,
// heure, client et prestation à gauche ; à droite le prix une seule fois
// (ambre si à encaisser, « Absent » en rouge) et, s'il n'est pas payé, un petit
// bouton « Encaisser » (option 1A). Toucher une ligne payée corrige le montant
// (option 3A).
class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne, required this.surEncaisser});
  final LigneHistorique ligne;
  final VoidCallback surEncaisser;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final l = ligne;
    final heure = formatHeure(TimeOfDay.fromDateTime(l.debut));
    final montant = l.montant;
    final absent = l.statut == StatutRendezVous.absent;
    final etat = absent
        ? 'absent'
        : montant == null
        ? 'à encaisser, ${formatPrix(l.prix)}'
        : 'encaissé, ${formatPrix(montant)}';
    final droite = absent
        ? Text(
            'Absent',
            style: textes.labelLarge!.copyWith(
              color: CouleursStatut.absentTexte,
            ),
          )
        : Text(
            formatPrix(montant ?? l.prix),
            style: textes.labelLarge!.copyWith(
              color: montant == null
                  ? CouleursStatut.aCloturerTexte
                  : Couleurs.texte,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    return Semantics(
      container: true,
      label: '$heure, ${l.clientNom}, ${l.prestation}, ${l.coiffeur}, $etat',
      child: InkWell(
        onTap: absent || montant == null ? null : surEncaisser,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: Espaces.s2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Couleurs.separateur)),
          ),
          child: Row(
            children: [
              Avatar(nom: l.coiffeur, taille: 28),
              const SizedBox(width: Espaces.s2),
              ExcludeSemantics(
                child: SizedBox(
                  width: 52,
                  child: Text(
                    heure,
                    style: textes.labelLarge!.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.clientNom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textes.titleSmall,
                      ),
                      Text(
                        l.prestation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textes.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Espaces.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ExcludeSemantics(child: droite),
                  if (!absent && montant == null)
                    TextButton(
                      onPressed: surEncaisser,
                      style: TextButton.styleFrom(
                        foregroundColor: CouleursStatut.aCloturerTexte,
                        backgroundColor: CouleursStatut.aCloturerFond,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(zoneTactileMin, 36),
                        // Bouton, pas lien : sans le soulignement des boutons
                        // texte de la charte.
                        textStyle: textes.labelLarge!.copyWith(
                          decoration: TextDecoration.none,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Espaces.s3,
                        ),
                      ),
                      child: Text(
                        'Encaisser',
                        semanticsLabel: 'Encaisser $heure, ${l.clientNom}',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
