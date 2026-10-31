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
  String? nom = 'Amira Ben Salah';

  @override
  Future<String?> monNom() async => nom;

  // Adresse de la photo du salon (#105) ; null : image par défaut.
  String? photo;

  @override
  Future<String?> photoDuSalon() async => photo;

  @override
  Future<void> modifierMonNom(String nouveau) async {
    await _action('nom $nouveau');
    nom = nouveau;
  }

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
      prix: 20,
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
      prix: 80,
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
      prix: 25,
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
  // Refus de la base pour les actions (clôture, encaissement).
  ErreurSalon? erreurAction;
  final appels = <String>[];
  // « r1 terminee », « r2 encaisse 18.5 », « r2 corrige 19.0 ».
  final actions = <String>[];
  List<LigneHistorique> lignesHistorique = [
    LigneHistorique(
      id: 'r2',
      coiffeurId: 'c2',
      coiffeur: 'Youssef',
      debut: DateTime(2030, 1, 7, 9),
      statut: StatutRendezVous.terminee,
      prestation: 'Couleur',
      prix: 80,
      clientNom: 'Karim',
      montant: 75,
    ),
    LigneHistorique(
      id: 'r4',
      coiffeurId: 'c1',
      coiffeur: 'Amira',
      debut: DateTime(2030, 1, 7, 9, 30),
      statut: StatutRendezVous.terminee,
      prestation: 'Coupe',
      prix: 20,
      clientNom: 'Salma',
    ),
    LigneHistorique(
      id: 'r5',
      coiffeurId: 'c1',
      coiffeur: 'Amira',
      debut: DateTime(2030, 1, 8, 11),
      statut: StatutRendezVous.absent,
      prestation: 'Brushing',
      prix: 25,
      clientNom: 'Nour',
    ),
  ];

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

  Future<void> _action(String texte) async {
    final e = erreurAction;
    if (e != null) throw e;
    actions.add(texte);
  }

  @override
  Future<List<Prestation>> prestationsActives() async => const [
    Prestation(
      id: 'p1',
      nom: 'Coupe',
      prix: 20,
      dureeMinutes: 30,
      active: true,
    ),
    Prestation(
      id: 'p2',
      nom: 'Brushing',
      prix: 25,
      dureeMinutes: 30,
      active: true,
    ),
  ];

  // Créneaux libres renvoyés par creneauxLibres (#103).
  List<CreneauLibre> creneaux = [
    CreneauLibre(
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 7, 10, 30),
      instant: DateTime.utc(2030, 1, 7, 9, 30),
    ),
    CreneauLibre(
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 7, 11, 0),
      instant: DateTime.utc(2030, 1, 7, 10, 0),
    ),
  ];

  // Jours demandés à creneauxLibres (#104) : « 2030-1-9 c1 ».
  final joursCreneaux = <String>[];

  @override
  Future<List<CreneauLibre>> creneauxLibres(
    String prestationId,
    DateTime jour, {
    String? coiffeurId,
  }) async {
    joursCreneaux.add('${_date(jour)} ${coiffeurId ?? 'peu importe'}');
    return creneaux;
  }

  // Erreur levée par la prochaine réservation pour un client, puis remise à
  // null.
  ErreurSalon? erreurReservation;

  @override
  Future<void> reserverPourClient({
    required String nom,
    String? telephone,
    required String prestationId,
    required CreneauLibre creneau,
    String? coiffeurId,
  }) async {
    final e = erreurReservation;
    erreurReservation = null;
    if (e != null) throw e;
    actions.add(
      'passage $nom ${telephone ?? '-'} $prestationId '
      '${creneau.debut.hour}:${creneau.debut.minute} ${coiffeurId ?? 'peu importe'}',
    );
  }

  @override
  Future<void> cloturer(String rendezVousId, StatutRendezVous statut) =>
      _action('$rendezVousId ${statut.name}');

  // « r1 arrivé » ou « r1 arrivée annulée » (#102) ; l'heure d'arrivée est
  // celle de maintenant, comme en base.
  @override
  Future<void> marquerArrivee(String rendezVousId, {bool arrive = true}) async {
    await _action('$rendezVousId ${arrive ? 'arrivé' : 'arrivée annulée'}');
    rendezVous = [
      for (final r in rendezVous)
        r.id == rendezVousId
            ? RendezVous(
                id: r.id,
                coiffeurId: r.coiffeurId,
                debut: r.debut,
                fin: r.fin,
                statut: r.statut,
                prestation: r.prestation,
                dureeMinutes: r.dureeMinutes,
                clientNom: r.clientNom,
                clientTelephone: r.clientTelephone,
                prix: r.prix,
                montantEncaisse: r.montantEncaisse,
                arriveLe: arrive ? maintenant : null,
              )
            : r,
    ];
  }

  @override
  Future<void> encaisser(String rendezVousId, double montant) =>
      _action('$rendezVousId encaisse $montant');

  @override
  Future<void> corrigerEncaissement(String rendezVousId, double montant) =>
      _action('$rendezVousId corrige $montant');

  @override
  Future<List<LigneHistorique>> historique(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  }) async {
    appels.add('historique ${_date(du)}..${_date(au)} ${coiffeurId ?? 'tous'}');
    final e = erreur;
    if (e != null) throw e;
    return [
      for (final l in lignesHistorique)
        if (coiffeurId == null || l.coiffeurId == coiffeurId) l,
    ];
  }
}
