import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/format.dart';
import 'fuseau.dart';
import 'salon.dart';

// Plannings (#10, BF-K1, BF-K2, BF-G5). Les rendez-vous passent par la
// fonction SQL planning() : un coiffeur ne reçoit que les siens, avec le nom
// et le téléphone du client (jamais l'e-mail) ; le gérant, tout son salon.
// Toutes les dates sont des heures du salon (dates « murales », fuseau.dart).
//
// Clôture, encaissement, historique (#11, BF-K3, BF-K4, BF-G4) : règles
// vérifiées par la base (migration 20261025153145_cloture_encaissement.sql),
// l'app ne fait qu'afficher les refus.
//
// Client arrivé (#102, option 1A) : heure d'arrivée sur le rendez-vous,
// marquée par marquer_arrivee() (migration 20261030224554_client_arrive.sql).

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
    required this.prix,
    this.montantEncaisse,
    this.arriveLe,
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
  // Prix de la prestation, en dinars (numeric(12, 3)).
  final double prix;
  // Montant encaissé : renseigné pour le gérant seulement, null sinon.
  final double? montantEncaisse;
  // Heure d'arrivée du client au salon (#102) ; null : pas encore arrivé.
  final DateTime? arriveLe;

  // « Terminé » et « Client absent » : rendez-vous confirmé et commencé.
  bool cloturable(DateTime maintenant) =>
      statut == StatutRendezVous.confirmee && !debut.isAfter(maintenant);

  // « Client arrivé » : confirmé, du jour, pas encore clôturé (la base le
  // vérifie aussi).
  bool arriveePossible(DateTime maintenant) =>
      statut == StatutRendezVous.confirmee && memeJour(debut, maintenant);

  EtatRendezVous etat(DateTime maintenant) => switch (statut) {
    StatutRendezVous.terminee => EtatRendezVous.termine,
    StatutRendezVous.absent => EtatRendezVous.absent,
    // Client arrivé avant l'heure (#102) ; à l'heure, « En cours ».
    StatutRendezVous.confirmee when debut.isAfter(maintenant) =>
      arriveLe == null ? EtatRendezVous.aVenir : EtatRendezVous.arrive,
    StatutRendezVous.confirmee when fin.isAfter(maintenant) =>
      EtatRendezVous.enCours,
    StatutRendezVous.confirmee => EtatRendezVous.aCloturer,
  };
}

// État affiché d'un rendez-vous (#64) : son statut en base, et l'heure pour
// un rendez-vous confirmé (à venir, arrivé, en cours, ou fini mais pas
// clôturé).
enum EtatRendezVous {
  aVenir('À venir'),
  arrive('Arrivé'),
  enCours('En cours'),
  aCloturer('À clôturer'),
  termine('Terminé'),
  absent('Absent');

  const EtatRendezVous(this.libelle);
  final String libelle;
}

// Ligne de l'historique : rendez-vous terminé ou client absent, avec son
// encaissement s'il existe.
class LigneHistorique {
  const LigneHistorique({
    required this.id,
    required this.coiffeurId,
    required this.coiffeur,
    required this.debut,
    required this.statut,
    required this.prestation,
    required this.prix,
    required this.clientNom,
    this.montant,
  });

  final String id;
  final String coiffeurId;
  final String coiffeur;
  final DateTime debut;
  final StatutRendezVous statut;
  final String prestation;
  final double prix;
  final String clientNom;
  final double? montant;

  bool get aEncaisser => statut == StatutRendezVous.terminee && montant == null;
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
// Créneau libre (#103) : début à l'heure du salon et l'instant exact à
// renvoyer à la base.
class CreneauLibre {
  const CreneauLibre({
    required this.coiffeurId,
    required this.debut,
    required this.instant,
  });
  final String coiffeurId;
  final DateTime debut;
  final DateTime instant;
}

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
  // Nom du compte connecté (sa ligne utilisateurs), pour « Bonjour Amira ».
  Future<String?> monNom();
  // Photo du salon pour le bandeau de l'accueil (#105) : adresse publique,
  // null pour l'image par défaut.
  Future<String?> photoDuSalon();
  // Mes infos (#106, option A) : le nom seul (policy « modification de sa
  // ligne », colonnes nom et telephone).
  Future<void> modifierMonNom(String nom);
  Future<DateTime> maintenantAuSalon();
  Future<List<Coiffeur>> coiffeurs();
  // Du premier au dernier jour inclus ; coiffeurId null : tous ceux que le
  // compte peut voir (le gérant : toute l'équipe).
  Future<DonneesPlanning> periode(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  });

  // statut : terminee ou absent.
  Future<void> cloturer(String rendezVousId, StatutRendezVous statut);
  // Client arrivé (#102) : marque (arrive) ou annule son arrivée.
  Future<void> marquerArrivee(String rendezVousId, {bool arrive = true});

  // Client de passage (#103) : prestations proposées, créneaux libres d'un
  // jour (comme le site), rendez-vous créé par l'équipe.
  Future<List<Prestation>> prestationsActives();
  Future<List<CreneauLibre>> creneauxLibres(
    String prestationId,
    DateTime jour, {
    String? coiffeurId,
  });
  Future<void> reserverPourClient({
    required String nom,
    String? telephone,
    required String prestationId,
    required CreneauLibre creneau,
    String? coiffeurId,
  });
  // Gérant : premier encaissement d'un rendez-vous terminé, puis correction
  // du montant seulement.
  Future<void> encaisser(String rendezVousId, double montant);
  Future<void> corrigerEncaissement(String rendezVousId, double montant);
  // Gérant : rendez-vous terminés et clients absents, 31 jours au plus.
  Future<List<LigneHistorique>> historique(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  });
}

// Messages des refus propres aux plannings, puis ceux de la configuration.
String messageErreurPlanning(String? code, String message) {
  switch (code) {
    case 'PT403':
      return message.startsWith('Historique')
          ? 'Historique réservé au gérant du salon.'
          : 'Planning réservé à l\'équipe du salon.';
    case 'PT409':
      if (message.startsWith('Client arrivé')) {
        return 'Client arrivé : annulez d\'abord son arrivée.';
      }
      if (message.startsWith('Arrivée possible')) {
        return 'Arrivée possible seulement le jour du rendez-vous.';
      }
      if (message.startsWith('Rendez-vous déjà')) {
        return 'Ce rendez-vous est déjà clôturé.';
      }
      return message.startsWith('Seul')
          ? 'Seul un rendez-vous terminé peut être encaissé.'
          : 'Ce rendez-vous n\'a pas encore commencé : clôture impossible.';
    case 'PT404':
      return 'Ce rendez-vous n\'est plus disponible pour ce compte.';
    case 'PT400':
      return 'Période de 1 à 31 jours.';
    case '23505':
      return 'Ce rendez-vous est déjà encaissé.';
    case '23514':
      return 'Ce rendez-vous est déjà clôturé, ou le montant est négatif.';
    case '42501':
      return 'Action non autorisée avec ce compte.';
    default:
      return messageErreurBase(code);
  }
}

String _dateSql(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      throw ErreurSalon(messageErreurPlanning(erreur.code, erreur.message));
    } on ErreurSalon {
      rethrow;
    } catch (erreur) {
      throw ErreurSalon(messageErreurInattendue(erreur));
    }
  }

  @override
  String? get moi => _client.auth.currentUser?.id;

  @override
  Future<String?> monNom() => _appel(() async {
    final id = moi;
    if (id == null) return null;
    final ligne = await _client
        .from('utilisateurs')
        .select('nom')
        .eq('id', id)
        .maybeSingle();
    return ligne?['nom'] as String?;
  });

  @override
  Future<String?> photoDuSalon() => _appel(() async {
    final ligne = await _client
        .from('salons')
        .select('photo')
        .eq('id', _salonId)
        .single();
    return adressePhoto(_client, ligne['photo'] as String?);
  });

  @override
  Future<void> modifierMonNom(String nom) => _appel(
    () => _uneLigne(
      _client
          .from('utilisateurs')
          .update({'nom': nom})
          .eq('id', moi ?? '')
          .select('id'),
    ),
  );

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

    final rdv = _client.rpc(
      'planning',
      params: {
        'p_salon': _salonId,
        'p_du': _dateSql(du),
        'p_au': _dateSql(au),
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
            prix: (l['prix'] as num).toDouble(),
            montantEncaisse: (l['montant_encaisse'] as num?)?.toDouble(),
            arriveLe: switch (l['arrive_le'] as String?) {
              final a? => depuisUtc(DateTime.parse(a), fuseau),
              null => null,
            },
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

  // Une modification que la RLS ne laisse pas passer ne lève pas d'erreur :
  // elle ne touche aucune ligne. On le vérifie par la ligne renvoyée.
  Future<void> _uneLigne(Future<List<dynamic>> requete) async {
    if ((await requete).isEmpty) {
      throw const ErreurSalon('Action non autorisée avec ce compte.');
    }
  }

  @override
  Future<void> cloturer(String rendezVousId, StatutRendezVous statut) => _appel(
    () => _uneLigne(
      _client
          .from('reservations')
          .update({'statut': statut.name})
          .eq('id', rendezVousId)
          .select('id'),
    ),
  );

  @override
  Future<void> marquerArrivee(String rendezVousId, {bool arrive = true}) =>
      _appel(
        () => _client.rpc(
          'marquer_arrivee',
          params: {'p_reservation': rendezVousId, 'p_arrive': arrive},
        ),
      );

  @override
  Future<List<Prestation>> prestationsActives() => _appel(() async {
    final lignes = await _client
        .from('prestations')
        .select('id, nom, prix, duree_minutes, active')
        .eq('salon_id', _salonId)
        .eq('active', true)
        .order('nom', ascending: true);
    return [
      for (final l in lignes)
        Prestation(
          id: l['id'] as String,
          nom: l['nom'] as String,
          prix: (l['prix'] as num).toDouble(),
          dureeMinutes: l['duree_minutes'] as int,
          active: true,
        ),
    ];
  });

  @override
  Future<List<CreneauLibre>> creneauxLibres(
    String prestationId,
    DateTime jour, {
    String? coiffeurId,
  }) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    final lignes =
        await _client.rpc(
              'creneaux_disponibles',
              params: {
                'p_prestation': prestationId,
                'p_du': _dateSql(jour),
                'p_au': _dateSql(jour),
                'p_coiffeur': coiffeurId,
              },
            )
            as List;
    final creneaux = <String, CreneauLibre>{};
    for (final l in lignes) {
      final instant = DateTime.parse(l['debut'] as String);
      // Une heure par créneau, quel que soit le nombre de coiffeurs libres.
      creneaux.putIfAbsent(
        instant.toIso8601String(),
        () => CreneauLibre(
          coiffeurId: l['coiffeur_id'] as String,
          debut: depuisUtc(instant, fuseau),
          instant: instant,
        ),
      );
    }
    return creneaux.values.toList()..sort((a, b) => a.debut.compareTo(b.debut));
  });

  @override
  Future<void> reserverPourClient({
    required String nom,
    String? telephone,
    required String prestationId,
    required CreneauLibre creneau,
    String? coiffeurId,
  }) async {
    try {
      await _client.rpc(
        'reserver_pour_client',
        params: {
          'p_nom': nom,
          'p_telephone': telephone,
          'p_prestation': prestationId,
          'p_debut': creneau.instant.toUtc().toIso8601String(),
          'p_coiffeur': coiffeurId,
        },
      );
    } on PostgrestException catch (erreur) {
      throw ErreurSalon(switch (erreur.code) {
        'PT409' => 'Ce créneau vient d\'être pris. Choisissez-en un autre.',
        'PT400' => 'Indiquez le nom du client.',
        'PT403' => 'Action réservée à l\'équipe du salon.',
        _ => messageErreurBase(erreur.code),
      });
    } catch (erreur) {
      throw ErreurSalon(messageErreurInattendue(erreur));
    }
  }

  @override
  Future<void> encaisser(String rendezVousId, double montant) =>
      _appel(() async {
        await _client.from('encaissements').insert({
          'reservation_id': rendezVousId,
          'montant': montant,
          'encaisse_par': moi,
        });
      });

  @override
  Future<void> corrigerEncaissement(String rendezVousId, double montant) =>
      _appel(
        () => _uneLigne(
          _client
              .from('encaissements')
              .update({'montant': montant})
              .eq('reservation_id', rendezVousId)
              .select('id'),
        ),
      );

  @override
  Future<List<LigneHistorique>> historique(
    DateTime du,
    DateTime au, {
    String? coiffeurId,
  }) => _appel(() async {
    final fuseau = await _fuseauDuSalon();
    final lignes =
        await _client.rpc(
              'historique',
              params: {
                'p_salon': _salonId,
                'p_du': _dateSql(du),
                'p_au': _dateSql(au),
                'p_coiffeur': coiffeurId,
              },
            )
            as List;
    return [
      for (final l in lignes)
        LigneHistorique(
          id: l['id'] as String,
          coiffeurId: l['coiffeur_id'] as String,
          coiffeur: l['coiffeur'] as String,
          debut: depuisUtc(DateTime.parse(l['debut'] as String), fuseau),
          statut: StatutRendezVous.depuisSql(l['statut'] as String),
          prestation: l['prestation'] as String,
          prix: (l['prix'] as num).toDouble(),
          clientNom: l['client_nom'] as String,
          montant: (l['montant'] as num?)?.toDouble(),
        ),
    ];
  });
}
