import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/ui/format.dart';

// Doublure du dépôt du salon : données en mémoire, mêmes refus que la base
// pour ce que l'app doit savoir afficher (chevauchement de plages).
class FauxSalon implements DepotSalon {
  FauxSalon({List<Prestation>? prestations, List<Coiffeur>? coiffeurs})
    : _prestations =
          prestations ??
          [
            const Prestation(
              id: 'p1',
              nom: 'Coupe femme',
              prix: 35,
              dureeMinutes: 45,
              active: true,
            ),
            const Prestation(
              id: 'p2',
              nom: 'Barbe',
              prix: 10.5,
              dureeMinutes: 15,
              active: false,
            ),
          ],
      _coiffeurs = coiffeurs ?? [const Coiffeur(id: 'c1', nom: 'Amira')];

  final List<Prestation> _prestations;
  final List<Coiffeur> _coiffeurs;
  final plagesEnregistrees = <String, List<Plage>>{};
  final absencesEnregistrees = <String, List<Absence>>{};
  final competencesEnregistrees = <String, Set<String>>{
    'c1': {'p1'},
  };
  // Nombre de rendez-vous confirmés renvoyé par rendezVousPendant.
  int rendezVous = 0;
  // Erreur levée par la prochaine écriture, puis remise à null.
  ErreurSalon? prochaineErreur;
  // Erreur levée par la prochaine lecture de l'équipe, puis remise à null.
  ErreurSalon? erreurCoiffeurs;
  final journal = <String>[];
  var _suivant = 0;

  void _echecEventuel() {
    final erreur = prochaineErreur;
    prochaineErreur = null;
    if (erreur != null) throw erreur;
  }

  // Adresse de la photo du salon (#105) ; null : image par défaut.
  String? photo;

  // Délai minimum d'annulation en minutes (#118).
  int delaiAnnulation = 0;

  @override
  Future<IdentiteSalon> identite() async => IdentiteSalon(
    nom: 'Salon de démo',
    adresse: '1 rue de la Coupe',
    photo: photo,
    delaiAnnulationMinutes: delaiAnnulation,
  );

  // « délai 120 » (#118).
  final actionsDelai = <String>[];

  @override
  Future<void> definirDelaiAnnulation(int minutes) async {
    _echecEventuel();
    actionsDelai.add('délai $minutes');
    delaiAnnulation = minutes;
  }

  // « photo image/jpeg 3 octets », « photo retirée » (#105).
  final actionsPhoto = <String>[];

  @override
  Future<void> changerPhoto(Uint8List octets, String type) async {
    _echecEventuel();
    actionsPhoto.add('photo $type ${octets.length} octets');
    photo = 'https://exemple.test/photo-${actionsPhoto.length}.jpg';
  }

  @override
  Future<void> retirerPhoto() async {
    _echecEventuel();
    actionsPhoto.add('photo retirée');
    photo = null;
  }

  @override
  Future<List<Prestation>> prestations() async =>
      [..._prestations]..sort((a, b) => a.nom.compareTo(b.nom));

  @override
  Future<void> creerPrestation({
    required String nom,
    required double prix,
    required int dureeMinutes,
  }) async {
    _echecEventuel();
    journal.add('creer $nom $prix $dureeMinutes');
    _prestations.add(
      Prestation(
        id: 'n${_suivant++}',
        nom: nom,
        prix: prix,
        dureeMinutes: dureeMinutes,
        active: true,
      ),
    );
  }

  @override
  Future<void> modifierPrestation(
    String id, {
    required String nom,
    required double prix,
    required int dureeMinutes,
  }) async {
    _echecEventuel();
    journal.add('modifier $id $nom $prix $dureeMinutes');
    final i = _prestations.indexWhere((p) => p.id == id);
    _prestations[i] = Prestation(
      id: id,
      nom: nom,
      prix: prix,
      dureeMinutes: dureeMinutes,
      active: _prestations[i].active,
    );
  }

  @override
  Future<void> changerActivation(String id, {required bool active}) async {
    _echecEventuel();
    journal.add('activation $id $active');
    final i = _prestations.indexWhere((p) => p.id == id);
    final p = _prestations[i];
    _prestations[i] = Prestation(
      id: id,
      nom: p.nom,
      prix: p.prix,
      dureeMinutes: p.dureeMinutes,
      active: active,
    );
  }

  @override
  Future<List<Coiffeur>> coiffeurs() async {
    final erreur = erreurCoiffeurs;
    erreurCoiffeurs = null;
    if (erreur != null) throw erreur;
    return _coiffeurs;
  }

  @override
  Future<List<Plage>> plages(String coiffeurId) async => [
    ...?plagesEnregistrees[coiffeurId],
  ];

  @override
  Future<void> ajouterPlage(
    String coiffeurId, {
    required int jour,
    required TimeOfDay debut,
    required TimeOfDay fin,
  }) async {
    _echecEventuel();
    final existantes = plagesEnregistrees.putIfAbsent(coiffeurId, () => []);
    final chevauche = existantes.any(
      (p) =>
          p.jour == jour &&
          minutesDuJour(p.debut) < minutesDuJour(fin) &&
          minutesDuJour(debut) < minutesDuJour(p.fin),
    );
    if (chevauche) throw ErreurSalon(messageErreurBase('23P01'));
    journal.add(
      'plage $coiffeurId $jour ${formatHeure(debut)}-${formatHeure(fin)}',
    );
    existantes.add(
      Plage(id: 'h${_suivant++}', jour: jour, debut: debut, fin: fin),
    );
  }

  @override
  Future<void> supprimerPlage(String id) async {
    _echecEventuel();
    journal.add('supprimer plage $id');
    for (final plages in plagesEnregistrees.values) {
      plages.removeWhere((p) => p.id == id);
    }
  }

  // Date et heure au salon renvoyées par maintenantAuSalon.
  DateTime maintenant = DateTime(2030, 1, 6, 15, 30);

  @override
  Future<DateTime> maintenantAuSalon() async => maintenant;

  @override
  Future<List<Absence>> absences(String coiffeurId) async => [
    ...?absencesEnregistrees[coiffeurId],
  ];

  @override
  Future<void> ajouterAbsence(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
    String? motif,
  }) async {
    _echecEventuel();
    journal.add('absence $coiffeurId $debut $fin $motif');
    absencesEnregistrees
        .putIfAbsent(coiffeurId, () => [])
        .add(
          Absence(id: 'a${_suivant++}', debut: debut, fin: fin, motif: motif),
        );
  }

  @override
  Future<void> supprimerAbsence(String id) async {
    _echecEventuel();
    journal.add('supprimer absence $id');
    for (final absences in absencesEnregistrees.values) {
      absences.removeWhere((a) => a.id == id);
    }
  }

  @override
  Future<int> rendezVousPendant(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
  }) async => rendezVous;

  @override
  Future<Set<String>> competences(String coiffeurId) async => {
    ...?competencesEnregistrees[coiffeurId],
  };

  @override
  Future<void> ajouterCompetence(String coiffeurId, String prestationId) async {
    _echecEventuel();
    journal.add('ajouter competence $coiffeurId $prestationId');
    competencesEnregistrees.putIfAbsent(coiffeurId, () => {}).add(prestationId);
  }

  @override
  Future<void> retirerCompetence(String coiffeurId, String prestationId) async {
    _echecEventuel();
    journal.add('retirer competence $coiffeurId $prestationId');
    competencesEnregistrees[coiffeurId]?.remove(prestationId);
  }
}
