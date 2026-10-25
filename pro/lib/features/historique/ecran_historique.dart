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
// coiffeur. Encaissement ou correction du montant depuis chaque ligne.
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
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          IconButton(
            onPressed: _relire,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListeCharte(
        enfants: [
          SegmentedButton<_Periode>(
            segments: [
              for (final p in _Periode.values)
                ButtonSegment(value: p, label: Text(p.libelle)),
            ],
            selected: {_periode},
            showSelectedIcon: false,
            // Marge latérale réduite : « Mois dernier » tient sur une ligne à
            // 360 px (test/features/historique_test.dart).
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: Espaces.s1),
              ),
            ),
            onSelectionChanged: (choix) => setState(() {
              _periode = choix.first;
              _version++;
            }),
          ),
          const SizedBox(height: Espaces.s4),
          Chargement<_Donnees>(
            key: ValueKey('$_version-$_periode-$_coiffeur'),
            lire: _lire,
            afficher: (context, d, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FiltreCoiffeur(
                  coiffeurs: d.coiffeurs,
                  choisi: _coiffeur,
                  surChoix: (id) => setState(() {
                    _coiffeur = id;
                    _version++;
                  }),
                ),
                const SizedBox(height: Espaces.s4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Du ${formatDate(d.du).toLowerCase()} au ${formatDate(d.au).toLowerCase()}',
                    style: textes.titleMedium,
                  ),
                ),
                const SizedBox(height: Espaces.s3),
                _Totaux(lignes: d.lignes),
                const SizedBox(height: Espaces.s4),
                if (d.lignes.isEmpty)
                  Text(
                    'Aucune prestation réalisée ni absence sur cette période.',
                    style: textes.bodyLarge,
                  )
                else
                  _ListeParJour(lignes: d.lignes, surEncaisser: _encaisser),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltreCoiffeur extends StatelessWidget {
  const _FiltreCoiffeur({
    required this.coiffeurs,
    required this.choisi,
    required this.surChoix,
  });

  final List<Coiffeur> coiffeurs;
  final String? choisi;
  final ValueChanged<String?> surChoix;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text('Coiffeur', style: textes.labelLarge)),
        const SizedBox(height: Espaces.s2),
        Semantics(
          label: 'Coiffeur',
          child: DropdownButtonFormField<String?>(
            initialValue: choisi,
            isExpanded: true,
            style: textes.bodyLarge,
            items: [
              const DropdownMenuItem(value: null, child: Text('Tous')),
              for (final c in coiffeurs)
                DropdownMenuItem(value: c.id, child: Text(c.nom)),
            ],
            onChanged: surChoix,
          ),
        ),
      ],
    );
  }
}

class _Totaux extends StatelessWidget {
  const _Totaux({required this.lignes});
  final List<LigneHistorique> lignes;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final realisees = lignes
        .where((l) => l.statut == StatutRendezVous.terminee)
        .length;
    final absents = lignes.length - realisees;
    final aEncaisser = lignes.where((l) => l.aEncaisser).length;
    final total = lignes.fold<double>(0, (s, l) => s + (l.montant ?? 0));
    final chiffres = textes.bodyLarge!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaces.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total encaissé : ${formatPrix(total)}',
              style: textes.titleMedium,
            ),
            const SizedBox(height: Espaces.s1),
            Text(
              '$realisees prestation${realisees > 1 ? 's' : ''} réalisée${realisees > 1 ? 's' : ''}'
              ' · $absents absent${absents > 1 ? 's' : ''}',
              style: chiffres,
            ),
            if (aEncaisser > 0)
              Text('$aEncaisser à encaisser', style: chiffres),
          ],
        ),
      ),
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
          if (enfants.isNotEmpty) const SizedBox(height: Espaces.s3),
          Semantics(
            header: true,
            child: Text(formatDate(j), style: textes.titleSmall),
          ),
          const SizedBox(height: Espaces.s2),
        ]);
      }
      enfants.addAll([
        _CarteLigne(ligne: l, surEncaisser: () => surEncaisser(l)),
        const SizedBox(height: Espaces.s2),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: enfants,
    );
  }
}

class _CarteLigne extends StatelessWidget {
  const _CarteLigne({required this.ligne, required this.surEncaisser});
  final LigneHistorique ligne;
  final VoidCallback surEncaisser;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final l = ligne;
    final heure = formatHeure(TimeOfDay.fromDateTime(l.debut));
    final montant = l.montant;
    final etat = l.statut == StatutRendezVous.absent
        ? 'Client absent'
        : montant == null
        ? 'À encaisser · prix ${formatPrix(l.prix)}'
        : 'Encaissé : ${formatPrix(montant)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaces.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$heure  ${l.clientNom} · ${l.prestation}',
              style: textes.bodyLarge!.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(l.coiffeur, style: textes.bodySmall),
            const SizedBox(height: Espaces.s1),
            Text(etat, style: textes.titleSmall),
            if (l.statut == StatutRendezVous.terminee)
              TextButton(
                onPressed: surEncaisser,
                child: Text(
                  montant == null ? 'Encaisser' : 'Corriger le montant',
                  semanticsLabel:
                      '${montant == null ? 'Encaisser' : 'Corriger le montant de'} '
                      '$heure, ${l.clientNom}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
