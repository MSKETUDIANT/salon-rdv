import 'package:flutter/material.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';

// Doublure du dépôt des plannings. Comme la fonction SQL planning(), elle ne
// renvoie que les rendez-vous du coiffeur demandé quand coiffeurId est donné.
class FauxPlanning implements DepotPlanning {
  FauxPlanning({this.moi = 'c1'});

  @override
  final String? moi;
  DateTime maintenant = DateTime(2030, 1, 7, 10); // lundi
  List<Coiffeur> equipe = const [
    Coiffeur(id: 'c1', nom: 'Amira'),
    Coiffeur(id: 'c2', nom: 'Youssef'),
  ];
  List<RendezVous> rendezVous = [
    RendezVous(
      id: 'r1',
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 7, 9),
      fin: DateTime(2030, 1, 7, 9, 30),
      statut: StatutRendezVous.confirmee,
      prestation: 'Coupe',
      dureeMinutes: 30,
      clientNom: 'Salma',
      clientTelephone: '21620000000',
    ),
    RendezVous(
      id: 'r2',
      coiffeurId: 'c2',
      debut: DateTime(2030, 1, 7, 14),
      fin: DateTime(2030, 1, 7, 14, 45),
      statut: StatutRendezVous.terminee,
      prestation: 'Couleur',
      dureeMinutes: 45,
      clientNom: 'Karim',
    ),
    RendezVous(
      id: 'r3',
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 9, 11),
      fin: DateTime(2030, 1, 9, 11, 30),
      statut: StatutRendezVous.confirmee,
      prestation: 'Brushing',
      dureeMinutes: 30,
      clientNom: 'Nour',
    ),
  ];
  List<AbsencePlanning> absences = [
    AbsencePlanning(
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 7, 15),
      fin: DateTime(2030, 1, 7, 16),
      motif: 'Formation',
    ),
  ];
  // c1 : lundi et mercredi 9h-18h ; c2 : lundi 10h-19h.
  List<PlageCoiffeur> plages = const [
    PlageCoiffeur(
      coiffeurId: 'c1',
      plage: Plage(
        id: 'h1',
        jour: 1,
        debut: TimeOfDay(hour: 9, minute: 0),
        fin: TimeOfDay(hour: 18, minute: 0),
      ),
    ),
    PlageCoiffeur(
      coiffeurId: 'c1',
      plage: Plage(
        id: 'h2',
        jour: 3,
        debut: TimeOfDay(hour: 9, minute: 0),
        fin: TimeOfDay(hour: 18, minute: 0),
      ),
    ),
    PlageCoiffeur(
      coiffeurId: 'c2',
      plage: Plage(
        id: 'h3',
        jour: 1,
        debut: TimeOfDay(hour: 10, minute: 0),
        fin: TimeOfDay(hour: 19, minute: 0),
      ),
    ),
  ];
  ErreurSalon? erreur;
  final appels = <String>[];

  String _date(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  Future<DateTime> maintenantAuSalon() async => maintenant;

  @override
  Future<List<Coiffeur>> coiffeurs() async => equipe;

  @override
  Future<DonneesPlanning> periode(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  }) async {
    appels.add('${_date(du)}..${_date(au)} ${coiffeurId ?? 'tous'}');
    final e = erreur;
    if (e != null) throw e;
    final fin = DateTime(au.year, au.month, au.day + 1);
    bool dansPeriode(DateTime d) =>
        !d.isBefore(DateTime(du.year, du.month, du.day)) && d.isBefore(fin);
    bool pourLui(String c) => coiffeurId == null || c == coiffeurId;
    return DonneesPlanning(
      rendezVous: [
        for (final r in rendezVous)
          if (pourLui(r.coiffeurId) && dansPeriode(r.debut)) r,
      ],
      absences: [
        for (final a in absences)
          if (pourLui(a.coiffeurId)) a,
      ],
      plages: [
        for (final p in plages)
          if (pourLui(p.coiffeurId)) p,
      ],
    );
  }
}
