import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fuseau.dart';

// Configuration du salon par le gérant (#9) : prestations, équipe, horaires,
// absences, compétences. Les droits sont vérifiés par la base (RLS, migration
// 20261025043854_configuration_salon.sql) : l'app ne fait qu'afficher.

class Prestation {
  const Prestation({
    required this.id,
    required this.nom,
    required this.prix,
    required this.dureeMinutes,
    required this.active,
  });

  final String id;
  final String nom;
  // En dinars, au millime près (numeric(12, 3)).
  final double prix;
  final int dureeMinutes;
  final bool active;
}

class Coiffeur {
  const Coiffeur({required this.id, required this.nom});
  final String id;
  final String nom;
}

// Plage de travail hebdomadaire. jour : 1 = lundi ... 7 = dimanche.
class Plage {
  const Plage({
    required this.id,
    required this.jour,
    required this.debut,
    required this.fin,
  });
  final String id;
  final int jour;
  final TimeOfDay debut;
  final TimeOfDay fin;
}

// debut et fin : heures du salon (dates « murales », voir fuseau.dart).
class Absence {
  const Absence({
    required this.id,
    required this.debut,
    required this.fin,
    this.motif,
  });
  final String id;
  final DateTime debut;
  final DateTime fin;
  final String? motif;
}

// Identité du salon (#81) : nom, adresse, adresse publique de la photo (#105,
// null : image par défaut), délai minimum d'annulation en minutes (#118, 0 :
// jusqu'au début du rendez-vous).
class IdentiteSalon {
  const IdentiteSalon({
    required this.nom,
    this.adresse,
    this.photo,
    this.delaiAnnulationMinutes = 0,
  });
  final String nom;
  final String? adresse;
  final String? photo;
  final int delaiAnnulationMinutes;
}

// Erreur à afficher telle quelle au gérant.
class ErreurSalon implements Exception {
  const ErreurSalon(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class DepotSalon {
  Future<IdentiteSalon> identite();
  // Délai minimum d'annulation (#118, gérant) : 0 à 10 080 minutes.
  Future<void> definirDelaiAnnulation(int minutes);
  // Photo du salon (#105, gérant) : envoi dans l'espace « salons », puis
  // definir_photo_salon() ; l'ancien fichier est supprimé. type : type MIME.
  Future<void> changerPhoto(Uint8List octets, String type);
  // Retour à l'image par défaut ; le fichier est supprimé.
  Future<void> retirerPhoto();
  Future<List<Prestation>> prestations();
  Future<void> creerPrestation({
    required String nom,
    required double prix,
    required int dureeMinutes,
  });
  Future<void> modifierPrestation(
    String id, {
    required String nom,
    required double prix,
    required int dureeMinutes,
  });
  Future<void> changerActivation(String id, {required bool active});

  Future<List<Coiffeur>> coiffeurs();

  Future<List<Plage>> plages(String coiffeurId);
  Future<void> ajouterPlage(
    String coiffeurId, {
    required int jour,
    required TimeOfDay debut,
    required TimeOfDay fin,
  });
  Future<void> supprimerPlage(String id);

  // Date et heure actuelles au salon (pas celles du téléphone).
  Future<DateTime> maintenantAuSalon();

  // Absences en cours ou à venir, la plus proche d'abord. Toutes les heures
  // d'absence (lues, écrites, comparées) sont des heures du salon.
  Future<List<Absence>> absences(String coiffeurId);
  Future<void> ajouterAbsence(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
    String? motif,
  });
  Future<void> supprimerAbsence(String id);
  // Rendez-vous confirmés du coiffeur qui recouvrent [debut, fin).
  Future<int> rendezVousPendant(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
  });

  Future<Set<String>> competences(String coiffeurId);
  Future<void> ajouterCompetence(String coiffeurId, String prestationId);
  Future<void> retirerCompetence(String coiffeurId, String prestationId);
}

// Espace de stockage des photos de salon (migration 20261031000430).
const espacePhotos = 'salons';

// Adresse publique d'une photo de l'espace « salons », null sans photo.
String? adressePhoto(SupabaseClient client, String? chemin) => chemin == null
    ? null
    : client.storage.from(espacePhotos).getPublicUrl(chemin);

// Refus de l'API Storage à l'envoi d'une photo.
String messageErreurPhoto(String? statut) => switch (statut) {
  '413' => 'Photo trop lourde : 5 Mo au plus.',
  '415' || '400' => 'Format non accepté : JPEG, PNG ou WebP.',
  '403' || '401' => 'Photo réservée au gérant du salon.',
  _ => messageErreurInconnue,
};

// Messages des erreurs renvoyées par la base (codes PostgreSQL).
// Erreur hors base (#83) : sans réseau, un message clair ; sinon un message
// neutre, jamais d'erreur technique. Détection par le type, sans dart:io
// (l'app tourne aussi dans le navigateur).
const messageHorsReseau =
    'Pas de connexion internet. Vérifiez le réseau, puis réessayez.';
const messageErreurInconnue = 'Une erreur est survenue. Réessayez.';

bool erreurReseau(Object erreur) {
  if (erreur is TimeoutException) return true;
  final type = erreur.runtimeType.toString();
  return type.contains('Socket') ||
      type.contains('ClientException') ||
      type.contains('Handshake');
}

String messageErreurInattendue(Object erreur) =>
    erreurReseau(erreur) ? messageHorsReseau : messageErreurInconnue;

String messageErreurBase(String? code) {
  switch (code) {
    case '23P01':
      return 'Cette plage chevauche une autre plage de ce coiffeur.';
    case '23514':
      return 'Saisie refusée : vérifiez les valeurs (fin après le début, prix positif, durée et nom).';
    case '23505':
      return 'Cet élément existe déjà.';
    case '42501':
      return 'Action réservée au gérant du salon.';
    default:
      return 'L\'enregistrement a échoué. Vérifiez le réseau, puis réessayez.';
  }
}

String heureSql(TimeOfDay h) =>
    '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';

TimeOfDay heureDepuisSql(String texte) {
  final morceaux = texte.split(':');
  return TimeOfDay(
    hour: int.parse(morceaux[0]),
    minute: int.parse(morceaux[1]),
  );
}

class SalonSupabase implements DepotSalon {
  SalonSupabase(this._client, this._salonId);
  final SupabaseClient _client;
  final String _salonId;
  String? _fuseau;

  // Fuseau du salon (salons.fuseau_horaire), lu une fois.
  Future<String> _fuseauDuSalon() async {
    return _fuseau ??=
        (await _client
                .from('salons')
                .select('fuseau_horaire')
                .eq('id', _salonId)
                .single())['fuseau_horaire']
            as String;
  }

  @override
  Future<DateTime> maintenantAuSalon() =>
      _appel(() async => depuisUtc(DateTime.now(), await _fuseauDuSalon()));

  @override
  Future<IdentiteSalon> identite() => _appel(() async {
    final ligne = await _client
        .from('salons')
        .select('nom, adresse, photo, delai_annulation_minutes')
        .eq('id', _salonId)
        .single();
    return IdentiteSalon(
      nom: ligne['nom'] as String,
      adresse: ligne['adresse'] as String?,
      photo: adressePhoto(_client, ligne['photo'] as String?),
      delaiAnnulationMinutes: (ligne['delai_annulation_minutes'] as int?) ?? 0,
    );
  });

  @override
  Future<void> definirDelaiAnnulation(int minutes) => _appel(
    () => _client.rpc(
      'definir_delai_annulation',
      params: {'p_salon': _salonId, 'p_minutes': minutes},
    ),
  );

  // Nom nouveau à chaque envoi : l'ancienne image en cache n'est jamais
  // resservie. Si l'enregistrement échoue, le fichier envoyé est retiré.
  @override
  Future<void> changerPhoto(Uint8List octets, String type) => _appel(() async {
    final extension = switch (type) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final chemin =
        '$_salonId/${DateTime.now().toUtc().microsecondsSinceEpoch}.$extension';
    final espace = _client.storage.from(espacePhotos);
    try {
      await espace.uploadBinary(
        chemin,
        octets,
        fileOptions: FileOptions(contentType: type),
      );
    } on StorageException catch (erreur) {
      throw ErreurSalon(messageErreurPhoto(erreur.statusCode));
    }
    try {
      await _definirPhoto(chemin);
    } catch (_) {
      await espace.remove([chemin]).catchError((_) => <FileObject>[]);
      rethrow;
    }
  });

  @override
  Future<void> retirerPhoto() => _appel(() => _definirPhoto(null));

  // Enregistre le chemin, puis supprime l'ancien fichier (sans bloquer : un
  // fichier oublié ne gêne pas l'affichage).
  Future<void> _definirPhoto(String? chemin) async {
    final lignes =
        await _client.rpc(
              'definir_photo_salon',
              params: {'p_salon': _salonId, 'p_chemin': chemin},
            )
            as List;
    final ancienne = lignes.isEmpty
        ? null
        : lignes.first['ancienne_photo'] as String?;
    if (ancienne != null && ancienne != chemin) {
      await _client.storage
          .from(espacePhotos)
          .remove([ancienne])
          .catchError((_) => <FileObject>[]);
    }
  }

  Future<T> _appel<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (erreur) {
      throw ErreurSalon(messageErreurBase(erreur.code));
    } on ErreurSalon {
      rethrow;
    } catch (erreur) {
      throw ErreurSalon(messageErreurInattendue(erreur));
    }
  }

  @override
  Future<List<Prestation>> prestations() => _appel(() async {
    final lignes = await _client
        .from('prestations')
        .select('id, nom, prix, duree_minutes, active')
        .eq('salon_id', _salonId)
        .order('nom', ascending: true);
    return [
      for (final l in lignes)
        Prestation(
          id: l['id'] as String,
          nom: l['nom'] as String,
          prix: (l['prix'] as num).toDouble(),
          dureeMinutes: l['duree_minutes'] as int,
          active: l['active'] as bool,
        ),
    ];
  });

  @override
  Future<void> creerPrestation({
    required String nom,
    required double prix,
    required int dureeMinutes,
  }) => _appel(
    () => _client.from('prestations').insert({
      'salon_id': _salonId,
      'nom': nom,
      'prix': prix,
      'duree_minutes': dureeMinutes,
    }),
  );

  // Seules ces colonnes sont modifiables par l'API (le salon ne change pas).
  @override
  Future<void> modifierPrestation(
    String id, {
    required String nom,
    required double prix,
    required int dureeMinutes,
  }) => _appel(
    () => _client
        .from('prestations')
        .update({'nom': nom, 'prix': prix, 'duree_minutes': dureeMinutes})
        .eq('id', id),
  );

  @override
  Future<void> changerActivation(String id, {required bool active}) => _appel(
    () => _client.from('prestations').update({'active': active}).eq('id', id),
  );

  // Noms des coiffeurs : coiffeurs_du_salon() (convention du projet).
  @override
  Future<List<Coiffeur>> coiffeurs() => _appel(() async {
    final lignes =
        await _client.rpc('coiffeurs_du_salon', params: {'p_salon': _salonId})
            as List;
    final coiffeurs = [
      for (final l in lignes)
        Coiffeur(id: l['id'] as String, nom: l['nom'] as String),
    ];
    coiffeurs.sort((a, b) => a.nom.compareTo(b.nom));
    return coiffeurs;
  });

  @override
  Future<List<Plage>> plages(String coiffeurId) => _appel(() async {
    final lignes = await _client
        .from('horaires')
        .select('id, jour_semaine, heure_debut, heure_fin')
        .eq('salon_id', _salonId)
        .eq('coiffeur_id', coiffeurId)
        .order('jour_semaine', ascending: true)
        .order('heure_debut', ascending: true);
    return [
      for (final l in lignes)
        Plage(
          id: l['id'] as String,
          jour: l['jour_semaine'] as int,
          debut: heureDepuisSql(l['heure_debut'] as String),
          fin: heureDepuisSql(l['heure_fin'] as String),
        ),
    ];
  });

  @override
  Future<void> ajouterPlage(
    String coiffeurId, {
    required int jour,
    required TimeOfDay debut,
    required TimeOfDay fin,
  }) => _appel(
    () => _client.from('horaires').insert({
      'salon_id': _salonId,
      'coiffeur_id': coiffeurId,
      'jour_semaine': jour,
      'heure_debut': heureSql(debut),
      'heure_fin': heureSql(fin),
    }),
  );

  @override
  Future<void> supprimerPlage(String id) =>
      _appel(() => _client.from('horaires').delete().eq('id', id));

  @override
  Future<List<Absence>> absences(String coiffeurId) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    final lignes = await _client
        .from('absences')
        .select('id, debut, fin, motif')
        .eq('salon_id', _salonId)
        .eq('coiffeur_id', coiffeurId)
        .gt('fin', DateTime.now().toUtc().toIso8601String())
        .order('debut', ascending: true);
    return [
      for (final l in lignes)
        Absence(
          id: l['id'] as String,
          debut: depuisUtc(DateTime.parse(l['debut'] as String), fuseau),
          fin: depuisUtc(DateTime.parse(l['fin'] as String), fuseau),
          motif: l['motif'] as String?,
        ),
    ];
  });

  @override
  Future<void> ajouterAbsence(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
    String? motif,
  }) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    await _client.from('absences').insert({
      'salon_id': _salonId,
      'coiffeur_id': coiffeurId,
      'debut': versUtc(debut, fuseau).toIso8601String(),
      'fin': versUtc(fin, fuseau).toIso8601String(),
      'motif': motif,
    });
  });

  @override
  Future<void> supprimerAbsence(String id) =>
      _appel(() => _client.from('absences').delete().eq('id', id));

  // Le gérant lit les réservations de son salon (policy de #3).
  @override
  Future<int> rendezVousPendant(
    String coiffeurId, {
    required DateTime debut,
    required DateTime fin,
  }) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    final lignes = await _client
        .from('reservations')
        .select('id')
        .eq('salon_id', _salonId)
        .eq('coiffeur_id', coiffeurId)
        .eq('statut', 'confirmee')
        .lt('debut', versUtc(fin, fuseau).toIso8601String())
        .gt('fin', versUtc(debut, fuseau).toIso8601String());
    return lignes.length;
  });

  @override
  Future<Set<String>> competences(String coiffeurId) => _appel(() async {
    final lignes = await _client
        .from('competences')
        .select('prestation_id')
        .eq('coiffeur_id', coiffeurId);
    return {for (final l in lignes) l['prestation_id'] as String};
  });

  @override
  Future<void> ajouterCompetence(String coiffeurId, String prestationId) =>
      _appel(
        () => _client.from('competences').insert({
          'coiffeur_id': coiffeurId,
          'prestation_id': prestationId,
        }),
      );

  @override
  Future<void> retirerCompetence(String coiffeurId, String prestationId) =>
      _appel(
        () => _client
            .from('competences')
            .delete()
            .eq('coiffeur_id', coiffeurId)
            .eq('prestation_id', prestationId),
      );
}
