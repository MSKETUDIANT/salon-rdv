import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// Accès à Supabase derrière deux interfaces, remplacées par des doublures dans
// les tests de widgets.

abstract interface class ServiceAuth {
  // E-mail du compte connecté, null sinon.
  String? get compte;
  Stream<String?> get changements;

  // Message d'erreur à afficher, null si la connexion a réussi.
  Future<String?> seConnecter(String email, String motDePasse);
  Future<void> seDeconnecter();
}

abstract interface class DepotRoles {
  // Rôles du compte connecté dans le salon de l'app.
  Future<List<String>> rolesDansLeSalon();
}

// Connexion des pros : e-mail et mot de passe (charte §5 : le code par e-mail
// est réservé aux clients du site).
class AuthSupabase implements ServiceAuth {
  AuthSupabase(this._client);
  final SupabaseClient _client;

  @override
  String? get compte => _client.auth.currentUser?.email;

  @override
  Stream<String?> get changements =>
      _client.auth.onAuthStateChange.map((etat) => etat.session?.user.email);

  @override
  Future<String?> seConnecter(String email, String motDePasse) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: motDePasse);
      return null;
    } on AuthException catch (erreur) {
      return messageErreurConnexion(erreur.code);
    } catch (_) {
      return messageErreurConnexion('reseau');
    }
  }

  @override
  Future<void> seDeconnecter() => _client.auth.signOut();
}

// Messages des erreurs de connexion (codes de Supabase Auth). Message neutre
// pour tout ce qui touche au compte : il ne révèle ni si l'adresse existe, ni
// si elle est confirmée.
String messageErreurConnexion(String? code) {
  switch (code) {
    case 'invalid_credentials':
    case 'email_not_confirmed':
    case 'user_not_found':
    case 'user_banned':
      return 'E-mail ou mot de passe incorrect.';
    case 'over_request_rate_limit':
      return 'Trop de tentatives. Réessayez dans une minute.';
    case 'reseau':
      return 'Connexion impossible. Vérifiez le réseau, puis réessayez.';
    default:
      return 'Une erreur est survenue. Réessayez.';
  }
}

// La policy « roles : lecture de ses rôles » (#3) limite déjà la lecture aux
// rôles du compte connecté ; le filtre utilisateur_id la double.
class RolesSupabase implements DepotRoles {
  RolesSupabase(this._client, this._salonId);
  final SupabaseClient _client;
  final String _salonId;

  @override
  Future<List<String>> rolesDansLeSalon() async {
    final utilisateur = _client.auth.currentUser;
    if (utilisateur == null) return [];
    final lignes = await _client
        .from('roles_utilisateur')
        .select('role')
        .eq('salon_id', _salonId)
        .eq('utilisateur_id', utilisateur.id);
    return [for (final ligne in lignes) ligne['role'] as String];
  }
}
