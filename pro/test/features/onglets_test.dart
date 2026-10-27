import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';

// Onglet « Salon » du coiffeur (#64) : ses horaires et absences, en lecture
// seule.

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('coiffeur : ses horaires et ses absences, sans modification', (
    tester,
  ) async {
    final planning = FauxPlanning();
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: themeCharte(),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: OngletSalonCoiffeur(planning: planning),
      ),
    );
    await tester.pumpAndSettle();

    // Ses rendez-vous seulement, sur 31 jours.
    expect(planning.appels, ['2030-1-7..2030-2-6 c1']);
    expect(find.text('Mes horaires'), findsOneWidget);
    // Lundi et mercredi 9h-18h, les autres jours non travaillés.
    expect(find.text('09:00 – 18:00'), findsNWidgets(2));
    expect(find.text('Ne travaille pas'), findsNWidgets(5));
    expect(find.text('Du Lundi 7 janvier, 15:00'), findsOneWidget);
    expect(find.text('Formation'), findsOneWidget);
    expect(find.textContaining('modifiés par le gérant'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
