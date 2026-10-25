import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/format.dart';
import 'fuseau.dart';
import 'salon.dart';

// Plannings (#10, BF-K1, BF-K2, BF-G5). Les rendez-vous passent par la
// fonction SQL planning() : un coiffeur ne reçoit que les siens, avec le nom
// et le téléphone du client (jamais l'e-mail) ; le gérant, tout son salon.
// Toutes les dates sont des heures du salon (dates « murales », fuseau.dart).

enum StatutRendezVous {
  confirmee('Confirmé'),
  terminee('Terminé'),
  absent('Client absent');

  const StatutRendezVous(this.libelle);
  final String libelle;

  static StatutRendezVous depuisSql(String valeur) =>
      values.firstWhere((s) => s.name == valeur, orElse: () => confirmee);
}

class RendezVous {
  const RendezVous({
    required this.id,
    required this.coiffeurId,
    required this.debut,
    required this.fin,
    required this.statut,
    required this.prestation,
    required this.dureeMinutes,
    required this.clientNom,
    this.clientTelephone,
  });

  final String id;
  final String coiffeurId;
  final DateTime debut;
  final DateTime fin;
  final StatutRendezVous statut;
  final String prestation;
  final int dureeMinutes;
  final String clientNom;
  final String? clientTelephone;
}

class AbsencePlanning {
  const AbsencePlanning({
    required this.coiffeurId,
    required this.debut,
    required this.fin,
    this.motif,
  });
  final String coiffeurId;
  final DateTime debut;
  final DateTime fin;
  final String? motif;
}

class PlageCoiffeur {
  const PlageCoiffeur({required this.coiffeurId, required this.plage});
  final String coiffeurId;
  final Plage plage;
}

// Ce qu'il faut pour afficher une période : rendez-vous, absences et plages
// de travail (pour griser les heures hors horaires).
class DonneesPlanning {
  const DonneesPlanning({
    required this.rendezVous,
    required this.absences,
    required this.plages,
  });
  final List<RendezVous> rendezVous;
  final List<AbsencePlanning> absences;
  final List<PlageCoiffeur> plages;

  List<RendezVous> rendezVousDu(String coiffeurId, DateTime jour) => [
    for (final r in rendezVous)
      if (r.coiffeurId == coiffeurId && memeJour(r.debut, jour)) r,
  ];

  // Absences qui touchent ce jour (une absence peut durer plusieurs jours).
  List<AbsencePlanning> absencesDu(String coiffeurId, DateTime jour) {
    final debutJour = DateTime(jour.year, jour.month, jour.day);
    final finJour = debutJour.add(const Duration(days: 1));
    return [
      for (final a in absences)
        if (a.coiffeurId == coiffeurId &&
            a.debut.isBefore(finJour) &&
            a.fin.isAfter(debutJour))
          a,
    ];
  }

  // Triées par heure de début (la base ne les renvoie pas dans l'ordre).
  List<Plage> plagesDu(String coiffeurId, DateTime jour) => [
    for (final p in plages)
      if (p.coiffeurId == coiffeurId && p.plage.jour == jour.weekday) p.plage,
  ]..sort((a, b) => minutesDuJour(a.debut).compareTo(minutesDuJour(b.debut)));
}

bool memeJour(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Lundi de la semaine qui contient ce jour.
DateTime lundiDe(DateTime jour) {
  final d = DateTime(jour.year, jour.month, jour.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

abstract interface class DepotPlanning {
  // Compte connecté (pour le planning « à moi » du coiffeur).
  String? get moi;
  Future<DateTime> maintenantAuSalon();
  Future<List<Coiffeur>> coiffeurs();
  // Du premier au dernier jour inclus ; coiffeurId null : tous ceux que le
  // compte peut voir (le gérant : toute l'équipe).
  Future<DonneesPlanning> periode(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  });
}

class PlanningSupabase implements DepotPlanning {
  PlanningSupabase(this._client, this._salonId);
  final SupabaseClient _client;
  final String _salonId;
  String? _fuseau;

  Future<String> _fuseauDuSalon() async {
    return _fuseau ??=
        (await _client
                .from('salons')
                .select('fuseau_horaire')
                .eq('id', _salonId)
                .single())['fuseau_horaire']
            as String;
  }

  Future<T> _appel<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (erreur) {
      throw ErreurSalon(
        erreur.code == 'PT403'
            ? 'Planning réservé à l\'équipe du salon.'
            : messageErreurBase(erreur.code),
      );
    } on ErreurSalon {
      rethrow;
    } catch (_) {
      throw ErreurSalon(messageErreurBase(null));
    }
  }

  @override
  String? get moi => _client.auth.currentUser?.id;

  @override
  Future<DateTime> maintenantAuSalon() =>
      _appel(() async => depuisUtc(DateTime.now(), await _fuseauDuSalon()));

  @override
  Future<List<Coiffeur>> coiffeurs() => _appel(() async {
    final lignes =
        await _client.rpc('coiffeurs_du_salon', params: {'p_salon': _salonId})
            as List;
    return [
      for (final l in lignes)
        Coiffeur(id: l['id'] as String, nom: l['nom'] as String),
    ]..sort((a, b) => a.nom.compareTo(b.nom));
  });

  @override
  Future<DonneesPlanning> periode(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  }) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final rdv = _client.rpc(
      'planning',
      params: {
        'p_salon': _salonId,
        'p_du': date(du),
        'p_au': date(au),
        'p_coiffeur': coiffeurId,
      },
    );

    // Absences qui recouvrent la période (bornes à l'heure du salon).
    var absences = _client
        .from('absences')
        .select('coiffeur_id, debut, fin, motif')
        .eq('salon_id', _salonId)
        .lt(
          'debut',
          versUtc(
            DateTime(au.year, au.month, au.day + 1),
            fuseau,
          ).toIso8601String(),
        )
        .gt(
          'fin',
          versUtc(
            DateTime(du.year, du.month, du.day),
            fuseau,
          ).toIso8601String(),
        );
    var horaires = _client
        .from('horaires')
        .select('id, coiffeur_id, jour_semaine, heure_debut, heure_fin')
        .eq('salon_id', _salonId);
    if (coiffeurId != null) {
      absences = absences.eq('coiffeur_id', coiffeurId);
      horaires = horaires.eq('coiffeur_id', coiffeurId);
    }

    final resultats = await Future.wait<dynamic>([rdv, absences, horaires]);
    return DonneesPlanning(
      rendezVous: [
        for (final l in resultats[0] as List)
          RendezVous(
            id: l['id'] as String,
            coiffeurId: l['coiffeur_id'] as String,
            debut: depuisUtc(DateTime.parse(l['debut'] as String), fuseau),
            fin: depuisUtc(DateTime.parse(l['fin'] as String), fuseau),
            statut: StatutRendezVous.depuisSql(l['statut'] as String),
            prestation: l['prestation'] as String,
            dureeMinutes: l['duree_minutes'] as int,
            clientNom: l['client_nom'] as String,
            clientTelephone: l['client_telephone'] as String?,
          ),
      ],
      absences: [
        for (final l in resultats[1] as List)
          AbsencePlanning(
            coiffeurId: l['coiffeur_id'] as String,
            debut: depuisUtc(DateTime.parse(l['debut'] as String), fuseau),
            fin: depuisUtc(DateTime.parse(l['fin'] as String), fuseau),
            motif: l['motif'] as String?,
          ),
      ],
      plages: [
        for (final l in resultats[2] as List)
          PlageCoiffeur(
            coiffeurId: l['coiffeur_id'] as String,
            plage: Plage(
              id: l['id'] as String,
              jour: l['jour_semaine'] as int,
              debut: heureDepuisSql(l['heure_debut'] as String),
              fin: heureDepuisSql(l['heure_fin'] as String),
            ),
          ),
      ],
    );
  });
}
