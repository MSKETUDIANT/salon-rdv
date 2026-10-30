import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/roles.dart';
import '../../data/salon.dart';
import '../../data/session.dart';
import '../../ui/charte.dart';
import '../aujourdhui/ecran_aujourdhui.dart';
import '../planning/ecran_mon_planning.dart';
import '../planning/ecran_planning_equipe.dart';
import 'onglets.dart';

// Un espace (#64) : barre d'onglets en bas, Accueil (#72), Planning, Salon,
// Profil (#73). Gérant : le salon entier (planning de l'équipe #10, historique #11,
// configuration #9) ; coiffeur : ses rendez-vous, ses horaires et absences en
// lecture seule. Chaque onglet se charge à sa première ouverture et garde son
// état ensuite.
class EcranEspace extends StatefulWidget {
  const EcranEspace({
    super.key,
    required this.espace,
    required this.salon,
    required this.planning,
    required this.compte,
    required this.surBascule,
    required this.surDeconnexion,
    required this.changerMotDePasse,
    this.autreEspace,
  });

  final Espace espace;
  final DepotSalon salon;
  final DepotPlanning planning;
  final String compte;
  // Gérant qui est aussi coiffeur : bascule vers l'autre espace.
  final Espace? autreEspace;
  final ValueChanged<Espace> surBascule;
  final VoidCallback surDeconnexion;
  // Changement de mot de passe, depuis le profil (#107).
  final Future<ErreurMotDePasse?> Function(String actuel, String nouveau)
  changerMotDePasse;

  @override
  State<EcranEspace> createState() => _EcranEspaceState();
}

class _EcranEspaceState extends State<EcranEspace> {
  int _onglet = 0;
  final _ouverts = <int>{0};

  @override
  Widget build(BuildContext context) {
    final gerant = widget.espace == Espace.gerant;
    Widget onglet(int i) => switch (i) {
      0 => EcranAujourdhui(
        planning: widget.planning,
        gerant: gerant,
        actif: _onglet == 0,
      ),
      1 =>
        gerant
            ? EcranPlanningEquipe(planning: widget.planning)
            : EcranMonPlanning(planning: widget.planning),
      2 =>
        gerant
            ? OngletSalonGerant(salon: widget.salon, planning: widget.planning)
            : OngletSalonCoiffeur(planning: widget.planning),
      _ => OngletProfil(
        compte: widget.compte,
        espace: widget.espace,
        planning: widget.planning,
        autreEspace: widget.autreEspace,
        surBascule: widget.surBascule,
        surDeconnexion: widget.surDeconnexion,
        changerMotDePasse: widget.changerMotDePasse,
      ),
    };
    return Scaffold(
      body: IndexedStack(
        index: _onglet,
        children: [
          for (var i = 0; i < 4; i++)
            _ouverts.contains(i) ? onglet(i) : const SizedBox.shrink(),
        ],
      ),
      // Filet `separateur` au-dessus de la barre (charte §4).
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Couleurs.separateur)),
        ),
        child: NavigationBar(
          selectedIndex: _onglet,
          onDestinationSelected: (i) => setState(() {
            _onglet = i;
            _ouverts.add(i);
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Planning',
            ),
            NavigationDestination(
              icon: Icon(Icons.content_cut_outlined),
              selectedIcon: Icon(Icons.content_cut),
              label: 'Salon',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
