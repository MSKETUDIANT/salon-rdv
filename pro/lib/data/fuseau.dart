import 'package:timezone/data/latest_10y.dart' as donnees_fuseaux;
import 'package:timezone/timezone.dart' as tz;

// Heures du salon (salons.fuseau_horaire, ex. Africa/Tunis), quel que soit le
// fuseau du téléphone du gérant. Dans l'app, une date « murale » est un
// DateTime sans fuseau qui se lit à l'heure du salon ; la base reçoit et
// renvoie de l'UTC.

var _pret = false;

// Base des fuseaux IANA (10 ans autour d'aujourd'hui), chargée une fois.
void initialiserFuseaux() {
  if (_pret) return;
  donnees_fuseaux.initializeTimeZones();
  _pret = true;
}

// 9h00 « au salon » → instant UTC.
DateTime versUtc(DateTime murale, String fuseau) {
  initialiserFuseaux();
  return tz.TZDateTime(
    tz.getLocation(fuseau),
    murale.year,
    murale.month,
    murale.day,
    murale.hour,
    murale.minute,
  ).toUtc();
}

// Instant (UTC ou non) → heure lue au salon, sans fuseau.
DateTime depuisUtc(DateTime instant, String fuseau) {
  initialiserFuseaux();
  final auSalon = tz.TZDateTime.from(instant.toUtc(), tz.getLocation(fuseau));
  return DateTime(
    auSalon.year,
    auSalon.month,
    auSalon.day,
    auSalon.hour,
    auSalon.minute,
  );
}
