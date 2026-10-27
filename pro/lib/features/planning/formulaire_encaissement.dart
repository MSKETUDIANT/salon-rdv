import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/format.dart';

// Encaissement d'un rendez-vous terminé par le gérant (BF-G4) : montant payé
// au salon, prérempli avec le prix de la prestation, modifiable. Avec
// montantActuel, correction du montant déjà encaissé (montant seulement).
// Renvoie true si le montant a été enregistré.
class FormulaireEncaissement extends StatefulWidget {
  const FormulaireEncaissement({
    super.key,
    required this.planning,
    required this.rendezVousId,
    required this.resume,
    required this.prix,
    this.montantActuel,
  });

  final DepotPlanning planning;
  final String rendezVousId;
  // « Lundi 7 janvier, 09:00 · Salma · Coupe ».
  final String resume;
  final double prix;
  final double? montantActuel;

  @override
  State<FormulaireEncaissement> createState() => _FormulaireEncaissementState();
}

class _FormulaireEncaissementState extends State<FormulaireEncaissement> {
  late final _montant = TextEditingController(
    text: formatPrix(widget.montantActuel ?? widget.prix).replaceAll(' DT', ''),
  );
  String? _erreurMontant;
  String? _erreur;
  bool _enCours = false;

  bool get _correction => widget.montantActuel != null;

  @override
  void dispose() {
    _montant.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final montant = lirePrix(_montant.text);
    setState(() {
      _erreur = null;
      _erreurMontant = montant == null
          ? 'Indiquez un montant positif, par exemple 35 ou 10,500.'
          : null;
    });
    if (montant == null) return;

    setState(() => _enCours = true);
    try {
      if (_correction) {
        await widget.planning.corrigerEncaissement(
          widget.rendezVousId,
          montant,
        );
      } else {
        await widget.planning.encaisser(widget.rendezVousId, montant);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ErreurSalon catch (erreur) {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreur = erreur.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_correction ? 'Corriger le montant' : 'Encaisser'),
      ),
      body: ListeCharte(
        enfants: [
          Text(widget.resume, style: textes.bodyLarge),
          const SizedBox(height: Espaces.s1),
          Text(
            'Prix de la prestation : ${formatPrix(widget.prix)}',
            style: textes.bodySmall,
          ),
          const SizedBox(height: Espaces.s6),
          Champ(
            libelle: 'Montant payé au salon (DT)',
            controleur: _montant,
            erreur: _erreurMontant,
            aide: 'Exemple : 35 ou 10,500',
            clavier: const TextInputType.numberWithOptions(decimal: true),
            actionClavier: TextInputAction.done,
            surValidation: _enregistrer,
          ),
          if (_correction) ...[
            const SizedBox(height: Espaces.s4),
            Text(
              'Montant enregistré : ${formatPrix(widget.montantActuel!)}. '
              'L\'ancien montant ne sera pas conservé.',
              style: textes.bodySmall,
            ),
          ],
          const SizedBox(height: Espaces.s6),
          if (_erreur != null) ...[
            MessageErreur(_erreur!),
            const SizedBox(height: Espaces.s3),
          ],
          Bouton(
            libelle: _correction ? 'Enregistrer la correction' : 'Encaisser',
            libelleChargement: 'Enregistrement…',
            chargement: _enCours,
            pleineLargeur: true,
            surAppui: _enregistrer,
          ),
        ],
      ),
    );
  }
}
