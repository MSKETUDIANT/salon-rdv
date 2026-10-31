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
  // Changement de mot de passe du compte connecté (#107) : null si réussi.
  Future<ErreurMotDePasse?> changerMotDePasse(String actuel, String nouveau);
  // « Pas encore de mot de passe, ou oublié ? » (#148, qui réunit le mot de
  // passe oublié de #39 et la première connexion de #145) : code à 6 chiffres
  // envoyé à l'adresse d'un compte existant (coiffeur invité compris : son
  // compte est créé par l'e-mail d'invitation), puis code et mot de passe
  // choisi ; le compte est alors connecté. null si réussi.
  Future<ErreurOubli?> envoyerCode(String email);
  Future<ErreurOubli?> connecterAvecCode(
    String email,
    String code,
    String motDePasse,
  );
}

// Refus du parcours « Recevoir un code ». Jamais de message qui dirait si
// l'adresse a un compte.
enum ErreurOubli {
  codeInvalide(
    'Code incorrect ou expiré. Vérifiez-le, ou demandez un nouveau code.',
  ),
  tropFaible('Mot de passe trop faible : 8 caractères au moins.'),
  tropDeDemandes('Trop de demandes. Réessayez dans une minute.'),
  reseau('Connexion impossible. Vérifiez le réseau, puis réessayez.'),
  autre('Une erreur est survenue. Réessayez.');

  const ErreurOubli(this.message);
  final String message;
}

// Codes de Supabase Auth du parcours « Recevoir un code ».
ErreurOubli erreurOubli(String? code) => switch (code) {
  'otp_expired' || 'invalid_credentials' => ErreurOubli.codeInvalide,
  'weak_password' => ErreurOubli.tropFaible,
  'over_email_send_rate_limit' ||
  'over_request_rate_limit' => ErreurOubli.tropDeDemandes,
  _ => ErreurOubli.autre,
};

// Refus d'un changement de mot de passe, avec le champ concerné.
enum ErreurMotDePasse {
  actuelIncorrect('Mot de passe actuel incorrect.', actuel: true),
  tropFaible('Mot de passe trop faible : 8 caractères au moins.'),
  identique("Choisissez un mot de passe différent de l'actuel."),
  tropDeTentatives('Trop de tentatives. Réessayez dans une minute.'),
  reseau('Connexion impossible. Vérifiez le réseau, puis réessayez.'),
  autre('Une erreur est survenue. Réessayez.');

  const ErreurMotDePasse(this.message, {this.actuel = false});
  final String message;
  // Erreur du champ « Mot de passe actuel » (sinon : du nouveau, ou générale).
  final bool actuel;
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

  // Jamais de compte créé ici : une adresse inconnue reçoit le même message
  // neutre (otp_disabled n'est pas dit), seule la limite d'envoi l'est.
  @override
  Future<ErreurOubli?> envoyerCode(String email) async {
    try {
      await _client.auth.signInWithOtp(email: email, shouldCreateUser: false);
      return null;
    } on AuthException catch (erreur) {
      final refus = erreurOubli(erreur.code);
      return refus == ErreurOubli.tropDeDemandes ? refus : null;
    } catch (_) {
      return ErreurOubli.reseau;
    }
  }

  // Le code (type email) ouvre la session et confirme l'adresse : la base
  // donne alors le rôle coiffeur d'une invitation en attente (#148), avant
  // que la porte lise les rôles. Puis le mot de passe choisi est enregistré.
  @override
  Future<ErreurOubli?> connecterAvecCode(
    String email,
    String code,
    String motDePasse,
  ) async {
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      await _client.auth.updateUser(UserAttributes(password: motDePasse));
      return null;
    } on AuthException catch (erreur) {
      return erreurOubli(erreur.code);
    } catch (_) {
      return ErreurOubli.reseau;
    }
  }

  // Le mot de passe actuel est vérifié par une reconnexion (la session reste
  // la même), puis remplacé. La longueur minimale est aussi imposée par
  // Supabase Auth (weak_password).
  @override
  Future<ErreurMotDePasse?> changerMotDePasse(
    String actuel,
    String nouveau,
  ) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) return ErreurMotDePasse.autre;
    try {
      await _client.auth.signInWithPassword(email: email, password: actuel);
    } on AuthException catch (erreur) {
      return erreur.code == 'over_request_rate_limit'
          ? ErreurMotDePasse.tropDeTentatives
          : ErreurMotDePasse.actuelIncorrect;
    } catch (_) {
      return ErreurMotDePasse.reseau;
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: nouveau));
      return null;
    } on AuthException catch (erreur) {
      return erreurMotDePasse(erreur.code);
    } catch (_) {
      return ErreurMotDePasse.reseau;
    }
  }
}

// Codes de Supabase Auth au remplacement du mot de passe.
// (Recevoir un code : erreurOubli, plus haut.)
ErreurMotDePasse erreurMotDePasse(String? code) => switch (code) {
  'weak_password' => ErreurMotDePasse.tropFaible,
  'same_password' => ErreurMotDePasse.identique,
  'over_request_rate_limit' => ErreurMotDePasse.tropDeTentatives,
  _ => ErreurMotDePasse.autre,
};

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
