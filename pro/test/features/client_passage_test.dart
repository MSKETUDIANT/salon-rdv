import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/formulaire_client_passage.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';

// Rendez-vous pour un client de passage (#103) : formulaire et bouton du
// planning. Droits et double réservation : reserver_pour_client.test.sql.

late FauxPlanning planning;

Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ecran,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => planning = FauxPlanning());

  testWidgets('gérant : nom requis, puis rendez-vous au premier créneau', (
    tester,
  ) async {
    await ouvrir(
      tester,
      FormulaireClientPassage(
        planning: planning,
        gerant: true,
        coiffeurId: 'c1',
      ),
    );
    expect(find.text('Coupe · 30 min'), findsOneWidget);
    expect(find.text('Peu importe'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);

    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(find.text('Indiquez le nom du client.'), findsOneWidget);
    expect(planning.actions, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'Salma');
    await tester.enterText(find.byType(TextField).at(1), '+21620000000');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Salma +21620000000 p1 10:30 c1']);
  });

  testWidgets('autre heure, « Peu importe », sans téléphone', (tester) async {
    await ouvrir(
      tester,
      FormulaireClientPassage(planning: planning, gerant: true),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Karim');
    await appuyer(tester, find.text('11:00'));
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Karim - p1 11:0 peu importe']);
  });

  testWidgets(
    'créneau pris entre-temps : message, on reste sur le formulaire',
    (tester) async {
      planning.erreurReservation = const ErreurSalon(
        'Ce créneau vient d\'être pris. Choisissez-en un autre.',
      );
      await ouvrir(
        tester,
        FormulaireClientPassage(planning: planning, gerant: true),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Nour');
      await appuyer(tester, find.text('Enregistrer le rendez-vous'));
      expect(find.textContaining('vient d\'être pris'), findsOneWidget);
      expect(find.text('Nouveau rendez-vous'), findsOneWidget);
    },
  );

  testWidgets('coiffeur : pas de choix du coiffeur ; bouton du planning', (
    tester,
  ) async {
    await ouvrir(tester, EcranMonPlanning(planning: planning));
    await appuyer(tester, find.text('Nouveau rendez-vous'));
    expect(find.text('Peu importe'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'Inès');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions.single, startsWith('passage Inès - p1 10:30 c1'));
    expect(find.text('Rendez-vous ajouté.'), findsOneWidget);
  });
}
