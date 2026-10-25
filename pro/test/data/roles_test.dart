import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/config.dart';
import 'package:salon_pro/data/roles.dart';
import 'package:salon_pro/data/session.dart';

void main() {
  group('espacesPro', () {
    test('client seul, ou aucun rôle : aucun espace', () {
      expect(espacesPro(['client']), isEmpty);
      expect(espacesPro([]), isEmpty);
    });

    test(
      'coiffeur ; gérant ; gérant et coiffeur (gérant d\'abord), client ignoré',
      () {
        expect(espacesPro(['coiffeur']), [Espace.coiffeur]);
        expect(espacesPro(['gerant', 'client']), [Espace.gerant]);
        expect(espacesPro(['client', 'coiffeur', 'gerant']), [
          Espace.gerant,
          Espace.coiffeur,
        ]);
      },
    );
  });

  test('configuration : variables manquantes nommées', () {
    expect(Config.manquantes(url: '', cle: '', salon: ''), [
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'SALON_ID',
    ]);
    expect(Config.manquantes(url: 'http://x', cle: 'k', salon: 's'), isEmpty);
  });

  test('messages des erreurs de connexion', () {
    expect(
      messageErreurConnexion('invalid_credentials'),
      'E-mail ou mot de passe incorrect.',
    );
    expect(messageErreurConnexion('reseau'), contains('Vérifiez le réseau'));
    expect(
      messageErreurConnexion('autre'),
      'Une erreur est survenue. Réessayez.',
    );
  });
}
