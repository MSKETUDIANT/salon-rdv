import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/ui/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  test('prix : sans décimales quand les millimes sont nuls, comme le site', () {
    expect(formatPrix(35), '35 DT');
    expect(formatPrix(10.5), '10,500 DT');
    expect(formatPrix(0.25), '0,250 DT');
  });

  test('prix saisi : virgule ou point, au millime, jamais négatif', () {
    expect(lirePrix('35'), 35);
    expect(lirePrix(' 10,5 '), 10.5);
    expect(lirePrix('10.500'), 10.5);
    expect(lirePrix('-1'), isNull);
    expect(lirePrix('1,2345'), isNull);
    expect(lirePrix('trente'), isNull);
    expect(lirePrix(''), isNull);
  });

  test('durée saisie : minutes entières, plus de 0, au plus 12 h', () {
    expect(lireDuree('45'), 45);
    expect(lireDuree('0'), isNull);
    expect(lireDuree('-5'), isNull);
    expect(lireDuree('4,5'), isNull);
    expect(lireDuree('721'), isNull);
  });

  test('durées, heures, dates en français', () {
    expect(formatDuree(45), '45 min');
    expect(formatDuree(60), '1 h');
    expect(formatDuree(90), '1 h 30');
    expect(formatHeure(const TimeOfDay(hour: 9, minute: 5)), '09:05');
    expect(
      formatDateHeure(DateTime(2030, 1, 7, 9, 30)),
      'Lundi 7 janvier, 09:30',
    );
    expect(formatDate(DateTime(2030, 1, 7)), 'Lundi 7 janvier');
  });

  test('heures de la base : « 09:00:00 » dans les deux sens', () {
    final h = heureDepuisSql('09:30:00');
    expect((h.hour, h.minute), (9, 30));
    expect(heureSql(const TimeOfDay(hour: 14, minute: 0)), '14:00');
  });

  test('erreurs de la base : messages clairs', () {
    expect(messageErreurBase('23P01'), contains('chevauche'));
    expect(messageErreurBase('42501'), 'Action réservée au gérant du salon.');
    expect(messageErreurBase('23514'), contains('vérifiez les valeurs'));
    expect(messageErreurBase(null), contains('réseau'));
  });
}
