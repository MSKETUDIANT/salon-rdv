import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/fuseau.dart';

// Les absences se saisissent à l'heure du salon (salons.fuseau_horaire),
// quel que soit le fuseau du téléphone du gérant.
void main() {
  test(
    'Tunis (UTC+1, sans heure d\'été) : 9h au salon = 8h UTC, et retour',
    () {
      expect(
        versUtc(DateTime(2030, 1, 7, 9), 'Africa/Tunis'),
        DateTime.utc(2030, 1, 7, 8),
      );
      expect(
        versUtc(DateTime(2030, 7, 1, 9), 'Africa/Tunis'),
        DateTime.utc(2030, 7, 1, 8),
      );
      expect(
        depuisUtc(DateTime.utc(2030, 1, 7, 8), 'Africa/Tunis'),
        DateTime(2030, 1, 7, 9),
      );
    },
  );

  test('fuseau à heure d\'été (Paris) : l\'écart suit la date', () {
    expect(
      versUtc(DateTime(2030, 1, 7, 9), 'Europe/Paris'),
      DateTime.utc(2030, 1, 7, 8),
    );
    expect(
      versUtc(DateTime(2030, 7, 1, 9), 'Europe/Paris'),
      DateTime.utc(2030, 7, 1, 7),
    );
  });

  test('autre continent : 9h à New York = 14h UTC en hiver', () {
    expect(
      versUtc(DateTime(2030, 1, 7, 9), 'America/New_York'),
      DateTime.utc(2030, 1, 7, 14),
    );
  });

  test('changement de jour : 0h30 au salon = la veille en UTC', () {
    expect(
      versUtc(DateTime(2030, 1, 7, 0, 30), 'Africa/Tunis'),
      DateTime.utc(2030, 1, 6, 23, 30),
    );
    expect(
      depuisUtc(DateTime.utc(2030, 1, 6, 23, 30), 'Africa/Tunis'),
      DateTime(2030, 1, 7, 0, 30),
    );
  });

  test('l\'heure du téléphone n\'entre pas en compte', () {
    final instant = DateTime.utc(2030, 1, 7, 8);
    // Le même instant, exprimé à l'heure locale de la machine de test.
    expect(
      depuisUtc(instant.toLocal(), 'Africa/Tunis'),
      DateTime(2030, 1, 7, 9),
    );
    // Une date murale se lit au salon, même si elle est marquée UTC.
    expect(
      versUtc(DateTime.utc(2030, 1, 7, 9), 'Africa/Tunis'),
      DateTime.utc(2030, 1, 7, 8),
    );
  });
}
