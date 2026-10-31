import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/gerant/ecran_coiffeur.dart';
import 'package:salon_pro/features/gerant/ecran_equipe.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_salon.dart';

// Écran « Équipe » du gérant (#9, #47) : liste des coiffeurs, salon sans
// coiffeur, erreur puis « Réessayer », ouverture d'une fiche.

Future<void> ouvrir(WidgetTester tester, FauxSalon salon) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: EcranEquipe(salon: salon),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));

  testWidgets('liste des coiffeurs, une carte par coiffeur', (tester) async {
    await ouvrir(
      tester,
      FauxSalon(
        coiffeurs: const [
          Coiffeur(id: 'c1', nom: 'Amira'),
          Coiffeur(id: 'c2', nom: 'Youssef'),
        ],
      ),
    );
    expect(find.text('Équipe'), findsOneWidget);
    expect(find.text('Amira'), findsOneWidget);
    expect(find.text('Youssef'), findsOneWidget);
    // Une ligne par coiffeur (#92) : avatar et nom ; la description est lue
    // par TalkBack.
    expect(
      find.bySemanticsLabel('Amira, horaires, absences et compétences'),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('salon sans coiffeur : message, pas de liste', (tester) async {
    await ouvrir(tester, FauxSalon(coiffeurs: const []));
    expect(
      find.textContaining("Aucun coiffeur pour l'instant."),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('horaires, absences')), findsNothing);
  });

  testWidgets('erreur de lecture : message, puis « Réessayer » relit', (
    tester,
  ) async {
    final salon = FauxSalon()
      ..erreurCoiffeurs = const ErreurSalon('Connexion impossible.');
    await ouvrir(tester, salon);
    expect(find.text('Connexion impossible.'), findsOneWidget);
    expect(find.text('Amira'), findsNothing);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Connexion impossible.'), findsNothing);
    expect(find.text('Amira'), findsOneWidget);
  });

  testWidgets('appui sur un coiffeur : sa fiche s\'ouvre', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await ouvrir(tester, FauxSalon());
    await tester.tap(find.text('Amira'));
    await tester.pumpAndSettle();
    expect(find.byType(EcranCoiffeur), findsOneWidget);
  });
}
