import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';

// Clôture par geste (#64) : « Terminé » ou « Client absent » est enregistré
// 5 s après le geste, le temps de toucher « Annuler ». Il part tout de suite
// si un autre geste suit, si l'écran se ferme (fermer) ou si l'app quitte le
// premier plan. Une fois enregistrée, la clôture reste définitive.
class ClotureDifferee with WidgetsBindingObserver {
  ClotureDifferee({
    required this.planning,
    required this.surEnregistree,
    required this.surErreur,
    this.surDepart,
    this.delai = const Duration(seconds: 5),
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  final DepotPlanning planning;
  // Après l'enregistrement : relire le planning.
  final VoidCallback surEnregistree;
  // Refus de la base : le rendez-vous reprend son état.
  final ValueChanged<String> surErreur;
  // L'enregistrement part (délai écoulé, écran quitté, app en arrière-plan) :
  // « Annuler » n'a plus d'effet, son message doit disparaître.
  final VoidCallback? surDepart;
  final Duration delai;

  RendezVous? _rendezVous;
  StatutRendezVous? _statut;
  Timer? _minuteur;

  // Statut en attente d'enregistrement pour ce rendez-vous, ou null.
  StatutRendezVous? enAttente(String rendezVousId) =>
      _rendezVous?.id == rendezVousId ? _statut : null;

  void programmer(RendezVous r, StatutRendezVous statut) {
    enregistrer();
    _rendezVous = r;
    _statut = statut;
    _minuteur = Timer(delai, enregistrer);
  }

  void annuler() {
    _minuteur?.cancel();
    _rendezVous = null;
    _statut = null;
  }

  Future<void> enregistrer() async {
    final r = _rendezVous;
    final statut = _statut;
    _minuteur?.cancel();
    _rendezVous = null;
    _statut = null;
    if (r == null || statut == null) return;
    surDepart?.call();
    try {
      await planning.cloturer(r.id, statut);
      surEnregistree();
    } on ErreurSalon catch (erreur) {
      surErreur(erreur.message);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) enregistrer();
  }

  void fermer() {
    WidgetsBinding.instance.removeObserver(this);
    enregistrer();
  }
}
