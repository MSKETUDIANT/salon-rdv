import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Fausse API Supabase (#47) : un vrai SupabaseClient dont le réseau est
// remplacé par MockClient. Chaque requête est notée ; la réponse vient de la
// table `reponses`, par « MÉTHODE /chemin ». Sans réponse prévue : 404.
class FausseApi {
  final requetes = <http.Request>[];
  final reponses = <String, http.Response Function(http.Request)>{};

  late final client = SupabaseClient(
    'http://api.test',
    'cle-anon',
    httpClient: MockClient(_repondre),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  // Sans réseau (#83) : chaque requête échoue comme sans connexion.
  bool horsReseau = false;

  Future<http.Response> _repondre(http.Request requete) async {
    requetes.add(requete);
    if (horsReseau) {
      throw http.ClientException('Failed host lookup', requete.url);
    }
    final cle = '${requete.method} ${requete.url.path}';
    final reponse = reponses[cle];
    if (reponse == null) {
      return _json({'message': 'Pas de réponse prévue : $cle'}, 404, requete);
    }
    return reponse(requete);
  }

  // La requête accompagne la réponse : PostgREST la relit (méthode, Accept).
  static http.Response _json(Object? corps, int statut, http.Request requete) =>
      http.Response.bytes(
        corps == null ? const [] : utf8.encode(jsonEncode(corps)),
        statut,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: requete,
      );

  // Réponse JSON pour une table (/rest/v1/<table>) ou une fonction
  // (/rest/v1/rpc/<nom>).
  void repondre(
    String methode,
    String chemin,
    Object? corps, {
    int statut = 200,
  }) => reponses['$methode /rest/v1/$chemin'] = (r) => _json(corps, statut, r);

  // Erreur PostgREST (code SQL ou PTxxx).
  void refuser(
    String methode,
    String chemin,
    String code, {
    String message = 'refus',
    int statut = 400,
  }) => repondre(methode, chemin, {
    'code': code,
    'message': message,
    'details': null,
    'hint': null,
  }, statut: statut);

  // Réponse d'une route d'Auth (/auth/v1/<chemin>).
  void repondreAuth(
    String methode,
    String chemin,
    Object? corps, {
    int statut = 200,
  }) => reponses['$methode /auth/v1/$chemin'] = (r) => _json(corps, statut, r);

  // Fuseau du salon, lu par .single() (objet JSON).
  void salon({String fuseau = 'Africa/Tunis'}) =>
      repondre('GET', 'salons', {'fuseau_horaire': fuseau});

  // Requêtes envoyées à une table ou une fonction.
  List<http.Request> vers(String chemin) => [
    for (final r in requetes)
      if (r.url.path == '/rest/v1/$chemin') r,
  ];

  // Session de connexion renvoyée par /auth/v1/token.
  static Map<String, Object?> session({
    String id = 'u1',
    String email = 'amira@salon.test',
  }) => {
    'access_token': 'jeton',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'refresh_token': 'renouvellement',
    'user': {
      'id': id,
      'aud': 'authenticated',
      'email': email,
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}
