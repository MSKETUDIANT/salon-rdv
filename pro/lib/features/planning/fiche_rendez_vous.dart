import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';
import 'formulaire_encaissement.dart';

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
