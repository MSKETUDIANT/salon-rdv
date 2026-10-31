import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/features/gerant/ecran_equipe.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Onglet « Salon » du gérant (#81) : identité du salon (nom, adresse,
// horaires d'ouverture lus dans la base, #129), listes à icônes avec un chiffre.

late FauxPlanning planning;

Future<void> ouvrir(WidgetTester tester, {FauxSalon? salon}) async {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: OngletSalonGerant(salon: salon ?? FauxSalon(), planning: planning),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => planning = FauxPlanning());

  testWidgets('identité : nom, adresse, horaires du jour et de la semaine', (
    tester,
  ) async {
    // Horaires d'ouverture lus dans la base (horaires_du_salon, #129) ;
    // lundi 7 janvier : Amira 09:00-18:00, Youssef 10:00-19:00.
    final salon = FauxSalon()
      ..ouverture = {
        1: (
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 19, minute: 0),
        ),
        3: (
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 18, minute: 0),
        ),
      };
    await ouvrir(tester, salon: salon);
    expect(find.text('Salon de démo'), findsOneWidget);
    expect(find.text('1 rue de la Coupe'), findsOneWidget);
    expect(find.text("Ouvert aujourd'hui · 09:00 – 19:00"), findsOneWidget);
    expect(
      find.text(
        'Lun 09:00 – 19:00\nMar fermé\nMer 09:00 – 18:00\nJeu–Dim fermé',
      ),
      findsOneWidget,
    );
    // Lecture de la semaine du lundi au dimanche.
    expect(planning.appels, ['2030-1-7..2030-1-13 tous']);
  });

  testWidgets('listes : un chiffre par ligne, « à encaisser » en évidence', (
    tester,
  ) async {
    await ouvrir(tester);
    expect(find.text('Activité'), findsOneWidget);
    expect(find.text('Configuration'), findsOneWidget);
    // Karim, terminé sans encaissement.
    expect(find.bySemanticsLabel('Historique, 1 à encaisser'), findsOneWidget);
    // Une prestation active sur deux.
    expect(find.bySemanticsLabel('Prestations, 1 prestation'), findsOneWidget);
    expect(find.bySemanticsLabel('Équipe, 1 coiffeur'), findsOneWidget);
    // Plus de grandes cartes.
    expect(find.text('Catalogue : créer, modifier, désactiver'), findsNothing);
  });

  testWidgets('rien à encaisser : nombre de rendez-vous de la semaine', (
    tester,
  ) async {
    planning.rendezVous = [
      for (final r in planning.rendezVous)
        if (r.statut != StatutRendezVous.terminee) r,
    ];
    await ouvrir(
      tester,
      salon: FauxSalon(
        coiffeurs: const [
          Coiffeur(id: 'c1', nom: 'Amira'),
          Coiffeur(id: 'c2', nom: 'Youssef'),
        ],
      ),
    );
    expect(
      find.bySemanticsLabel('Historique, 2 cette semaine'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Équipe, 2 coiffeurs'), findsOneWidget);
  });

  testWidgets('appui sur « Équipe » : l\'écran de l\'équipe s\'ouvre', (
    tester,
  ) async {
    await ouvrir(tester);
    final equipe = find.bySemanticsLabel('Équipe, 1 coiffeur');
    await tester.ensureVisible(equipe);
    await tester.pumpAndSettle();
    await tester.tap(equipe);
    await tester.pumpAndSettle();
    expect(find.byType(EcranEquipe), findsOneWidget);
  });

  // Horaires d'ouverture calculés par la base (horaires_du_salon, #129) ;
  // ici, seulement leur résumé.
  test('horaires : jours consécutifs identiques regroupés', () {
    (TimeOfDay, TimeOfDay) plage(int h1, int h2) =>
        (TimeOfDay(hour: h1, minute: 0), TimeOfDay(hour: h2, minute: 0));
    final ouverture = {
      1: plage(10, 18),
      for (var j = 2; j <= 6; j++) j: plage(9, 19),
    };
    expect(resumeHoraires(ouverture).split('\n'), [
      'Lun 10:00 – 18:00',
      'Mar–Sam 09:00 – 19:00',
      'Dim fermé',
    ]);
  });
}
