import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/historique/ecran_historique.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';

// Historique du gérant (#11). Droits et filtres côté base :
// supabase/tests/cloture_encaissement.test.sql ; ici, l'affichage. Dans la
// doublure, il est lundi 7 janvier 2030 ; lignes : r2 (Youssef, encaissé
// 75 DT), r4 (Amira, à encaisser), r5 (Amira, client absent).

late FauxPlanning planning;

Future<void> ouvrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 5400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: EcranHistorique(planning: planning),
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

  testWidgets('semaine en cours : totaux et lignes par jour', (tester) async {
    await ouvrir(tester);
    expect(planning.appels, ['historique 2030-1-7..2030-1-13 tous']);
    expect(
      find.text('Du lundi 7 janvier au dimanche 13 janvier'),
      findsOneWidget,
    );
    expect(find.text('Total encaissé : 75 DT'), findsOneWidget);
    expect(find.text('2 prestations réalisées · 1 absent'), findsOneWidget);
    expect(find.text('1 à encaisser'), findsOneWidget);

    expect(find.text('Lundi 7 janvier'), findsOneWidget);
    expect(find.text('Mardi 8 janvier'), findsOneWidget);
    expect(find.text('09:00  Karim · Couleur'), findsOneWidget);
    expect(find.text('À encaisser · prix 20 DT'), findsOneWidget);
    expect(find.text('Client absent'), findsOneWidget);
    expect(find.text('Encaisser'), findsOneWidget);
    expect(find.text('Corriger le montant'), findsOneWidget);
  });

  testWidgets('périodes : ce mois, puis mois précédent', (tester) async {
    await ouvrir(tester);
    await appuyer(tester, find.text('Ce mois'));
    expect(planning.appels.last, 'historique 2030-1-1..2030-1-31 tous');
    await appuyer(tester, find.text('Mois précédent'));
    expect(planning.appels.last, 'historique 2029-12-1..2029-12-31 tous');
    expect(
      find.text('Du samedi 1 décembre au lundi 31 décembre'),
      findsOneWidget,
    );
  });

  testWidgets('filtre coiffeur : Amira seulement', (tester) async {
    await ouvrir(tester);
    await appuyer(tester, find.byType(DropdownButtonFormField<String?>));
    await appuyer(tester, find.text('Amira').last);
    expect(planning.appels.last, 'historique 2030-1-7..2030-1-13 c1');
    expect(find.text('Total encaissé : 0 DT'), findsOneWidget);
    expect(find.text('1 prestation réalisée · 1 absent'), findsOneWidget);
    expect(find.text('09:00  Karim · Couleur'), findsNothing);
  });

  testWidgets('« Encaisser » depuis une ligne, puis relecture', (tester) async {
    await ouvrir(tester);
    await appuyer(tester, find.text('Encaisser'));
    expect(find.widgetWithText(TextField, '20'), findsOneWidget);
    await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
    expect(planning.actions, ['r4 encaisse 20.0']);
    expect(find.text('Encaissement enregistré.'), findsOneWidget);
    expect(planning.appels.length, 2);
  });

  testWidgets('période sans ligne : message', (tester) async {
    planning.lignesHistorique = [];
    await ouvrir(tester);
    expect(
      find.text('Aucune prestation réalisée ni absence sur cette période.'),
      findsOneWidget,
    );
    expect(find.text('Total encaissé : 0 DT'), findsOneWidget);
  });

  testWidgets('refus de la base : message et « Réessayer »', (tester) async {
    planning.erreur = const ErreurSalon(
      'Historique réservé au gérant du salon.',
    );
    await ouvrir(tester);
    expect(find.text('Historique réservé au gérant du salon.'), findsOneWidget);
    planning.erreur = null;
    await appuyer(tester, find.text('Réessayer'));
    expect(find.text('Total encaissé : 75 DT'), findsOneWidget);
  });
}
