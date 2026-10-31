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

  // Téléphone du salon (#129) ; null : pas de numéro.
  String? telephone;
  // « téléphone 71 234 567 », « téléphone retiré » (#129).
  final actionsTelephone = <String>[];

  // Horaires d'ouverture (#129) ; par défaut, du mardi au samedi.
  Map<int, (TimeOfDay, TimeOfDay)> ouverture = {
    for (var j = 2; j <= 6; j++)
      j: (
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 19, minute: 0),
      ),
  };

  @override
  Future<Map<int, (TimeOfDay, TimeOfDay)>> horairesOuverture() async =>
      ouverture;

  // Même règle que la base : 8 à 15 chiffres, espaces, points, tirets, « + »
  // au début ; vide : retiré.
  @override
  Future<void> definirTelephone(String telephone) async {
    _echecEventuel();
    final propre = telephone.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (propre.isEmpty) {
      actionsTelephone.add('téléphone retiré');
      this.telephone = null;
      return;
    }
    final chiffres = propre.replaceAll(RegExp(r'\D'), '').length;
    if (!RegExp(r'^\+?[0-9][0-9 .-]*[0-9]$').hasMatch(propre) ||
        chiffres < 8 ||
        chiffres > 15) {
      throw const ErreurSalon(messageTelephoneInvalide);
    }
    actionsTelephone.add('téléphone $propre');
    this.telephone = propre;
  }

  @override
  Future<IdentiteSalon> identite() async => IdentiteSalon(
    nom: 'Salon de démo',
    adresse: '1 rue de la Coupe',
    telephone: telephone,
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

  // Invitations en attente (#145) ; adresses des comptes qui existent déjà
  // (inviter les ajoute tout de suite à l'équipe).
  final invitationsEnAttente = <Invitation>[];
  final comptesExistants = <String, String>{};
  final actionsInvitation = <String>[];
  // E-mail d'invitation refusé (#148, limite d'envoi).
  bool emailRefuse = false;

  @override
  Future<List<Invitation>> invitations() async => invitationsEnAttente;

  // Mêmes refus que la base : adresse invalide, déjà dans l'équipe.
  // Réinviter une adresse en attente renvoie l'e-mail (#148).
  @override
  Future<ResultatInvitation> inviterCoiffeur({
    required String nom,
    required String email,
  }) async {
    _echecEventuel();
    final adresse = email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(adresse)) {
      throw const ErreurSalon('Adresse e-mail invalide.');
    }
    final compte = comptesExistants[adresse];
    if (compte != null) {
      if (_coiffeurs.any((c) => c.id == compte)) {
        throw const ErreurSalon("Déjà dans l'équipe.");
      }
      _coiffeurs.add(Coiffeur(id: compte, nom: nom));
      actionsInvitation.add('ajouté $adresse');
      return ResultatInvitation.ajoute;
    }
    final renvoi = invitationsEnAttente.any((i) => i.email == adresse);
    invitationsEnAttente
      ..removeWhere((i) => i.email == adresse)
      ..add(Invitation(id: 'inv-$adresse', nom: nom, email: adresse));
    actionsInvitation.add('${renvoi ? 'renvoyé' : 'invité'} $adresse');
    return emailRefuse
        ? ResultatInvitation.nonEnvoyee
        : ResultatInvitation.envoyee;
  }

  @override
  Future<void> annulerInvitation(String id) async {
    _echecEventuel();
    invitationsEnAttente.removeWhere((i) => i.id == id);
    actionsInvitation.add('annulé $id');
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

  // Comme definir_plages() (#151) : tout ou rien, le jour qui chevauche est
  // nommé ; remplace : la plage modifiée est retirée d'abord.
  @override
  Future<void> definirPlages(
    String coiffeurId, {
    required List<int> jours,
    required TimeOfDay debut,
    required TimeOfDay fin,
    String? remplace,
  }) async {
    _echecEventuel();
    final existantes = plagesEnregistrees.putIfAbsent(coiffeurId, () => []);
    final autres = existantes.where((p) => p.id != remplace).toList();
    for (final jour in {...jours}.toList()..sort()) {
      final chevauche = autres.any(
        (p) =>
            p.jour == jour &&
            minutesDuJour(p.debut) < minutesDuJour(fin) &&
            minutesDuJour(debut) < minutesDuJour(p.fin),
      );
      if (chevauche) {
        throw ErreurSalon(
          'Chevauche une plage existante le '
          '${nomsJours[jour - 1].toLowerCase()}.',
        );
      }
    }
    journal.add(
      'plages $coiffeurId ${({...jours}.toList()..sort()).join(',')} '
      '${formatHeure(debut)}-${formatHeure(fin)}'
      '${remplace == null ? '' : ' remplace $remplace'}',
    );
    existantes
      ..removeWhere((p) => p.id == remplace)
      ..addAll([
        for (final jour in {...jours}.toList()..sort())
          Plage(id: 'h${_suivant++}', jour: jour, debut: debut, fin: fin),
      ]);
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
