import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/ecran_planning_equipe.dart';
import 'package:salon_pro/features/planning/elements_planning.dart';
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

  group('créneau vide (#104)', creneauVide);
}

// Toucher d'un créneau vide (#104) : formulaire au jour et à l'heure touchés.
CreneauLibre creneau(int jour, int heure, int minute, [String c = 'c1']) =>
    CreneauLibre(
      coiffeurId: c,
      debut: DateTime(2030, 1, jour, heure, minute),
      instant: DateTime.utc(2030, 1, jour, heure - 1, minute),
    );

// Touche la frise à l'heure donnée ; debut : sa première heure (9:00 pour
// c1, 10:00 pour c2, leurs horaires).
Future<void> toucherA(
  WidgetTester tester,
  int heure,
  int minute, {
  int debut = 9,
}) async {
  final haut = tester.getTopLeft(find.byType(ColonneJour));
  final largeur = tester.getSize(find.byType(ColonneJour)).width;
  final dy = ((heure - debut) * 60 + minute) * pixelsParMinute;
  await tester.tapAt(haut + Offset(largeur / 2, dy + 1));
  await tester.pumpAndSettle();
}

void creneauVide() {
  testWidgets('formulaire d\'un autre jour : titre, créneau le plus proche', (
    tester,
  ) async {
    planning.creneaux = [creneau(9, 10, 30), creneau(9, 11, 0)];
    await ouvrir(
      tester,
      FormulaireClientPassage(
        planning: planning,
        gerant: false,
        heure: DateTime(2030, 1, 9, 10, 50),
      ),
    );
    expect(find.text('Heure, mercredi 9 janvier'), findsOneWidget);
    expect(planning.joursCreneaux, ['2030-1-9 c1']);
    await tester.enterText(find.byType(TextField).at(0), 'Rim');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Rim - p1 11:0 c1']);
  });

  testWidgets('à égalité, le créneau le plus tôt', (tester) async {
    planning.creneaux = [creneau(9, 10, 30), creneau(9, 11, 0)];
    await ouvrir(
      tester,
      FormulaireClientPassage(
        planning: planning,
        gerant: false,
        heure: DateTime(2030, 1, 9, 10, 45),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'Rim');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Rim - p1 10:30 c1']);
  });

  testWidgets('aucun créneau libre : « ce jour-là »', (tester) async {
    planning.creneaux = [];
    await ouvrir(
      tester,
      FormulaireClientPassage(
        planning: planning,
        gerant: false,
        heure: DateTime(2030, 1, 9, 10),
      ),
    );
    expect(
      find.text('Plus de créneau libre ce jour-là pour ce choix.'),
      findsOneWidget,
    );
  });

  testWidgets('coiffeur : un créneau vide touché ouvre le formulaire à cette '
      'heure', (tester) async {
    planning.creneaux = [creneau(7, 12, 0), creneau(7, 12, 15)];
    await ouvrir(tester, EcranMonPlanning(planning: planning));
    await toucherA(tester, 12, 7);
    expect(find.text('Heure, aujourd\'hui'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Lina');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Lina - p1 12:0 c1']);
    expect(find.text('Rendez-vous ajouté.'), findsOneWidget);
  });

  testWidgets('passé, absence, rendez-vous : pas de formulaire', (
    tester,
  ) async {
    await ouvrir(tester, EcranMonPlanning(planning: planning));
    // Maintenant 10:00 ; absence 15:00-16:00.
    await toucherA(tester, 9, 45);
    expect(find.text('Enregistrer le rendez-vous'), findsNothing);
    await toucherA(tester, 15, 30);
    expect(find.text('Enregistrer le rendez-vous'), findsNothing);
    // Le rendez-vous de 9:00 garde sa fiche.
    await toucherA(tester, 9, 10);
    expect(find.text('Enregistrer le rendez-vous'), findsNothing);
    expect(find.text('Rendez-vous'), findsOneWidget);
  });

  testWidgets('gérant : le coiffeur affiché est pré-choisi', (tester) async {
    planning.creneaux = [creneau(7, 13, 0, 'c2')];
    await ouvrir(tester, EcranPlanningEquipe(planning: planning));
    await appuyer(tester, find.text('Youssef'));
    await toucherA(tester, 13, 0, debut: 10);
    expect(planning.joursCreneaux, ['2030-1-7 c2']);
    await tester.enterText(find.byType(TextField).at(0), 'Sami');
    await appuyer(tester, find.text('Enregistrer le rendez-vous'));
    expect(planning.actions, ['passage Sami - p1 13:0 c2']);
  });
}
