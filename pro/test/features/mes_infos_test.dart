import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/roles.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../doublures/faux_planning.dart';

// Mes infos (#106, option A) : le nom seul, depuis le profil ; l'e-mail est
// affiché sans être modifiable. Droits : policy « modification de sa ligne »
// (rls_utilisateurs.test.sql).

late FauxPlanning planning;

Widget application(Widget ecran) => MaterialApp(
  theme: themeCharte(),
  locale: const Locale('fr'),
  supportedLocales: const [Locale('fr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: ecran,
);

Future<void> monter(WidgetTester tester, Widget ecran) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(application(ecran));
  await tester.pumpAndSettle();
}

Future<void> appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

Widget profil() => OngletProfil(
  compte: 'amira@salon.test',
  espace: Espace.coiffeur,
  planning: planning,
  surDeconnexion: () {},
  changerMotDePasse: (_, _) async => null,
);

// Ouvre « Modifier mes infos » depuis le profil.
Future<void> ouvrirMesInfos(WidgetTester tester) async {
  await monter(tester, profil());
  await appuyer(tester, find.bySemanticsLabel('Modifier mes infos'));
  expect(find.text('Mes infos'), findsOneWidget);
}

final champNom = find.byType(TextField);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() {
    planning = FauxPlanning();
    SharedPreferences.setMockInitialValues({});
    reinitialiserIndice();
  });

  testWidgets('nom pré-rempli, e-mail non modifiable', (tester) async {
    await ouvrirMesInfos(tester);
    expect(
      tester.widget<TextField>(champNom).controller!.text,
      'Amira Ben Salah',
    );
    expect(champNom, findsOneWidget);
    expect(
      find.bySemanticsLabel('E-mail, amira@salon.test, non modifiable'),
      findsOneWidget,
    );
  });

  testWidgets('nouveau nom : enregistré, profil relu, message', (tester) async {
    await ouvrirMesInfos(tester);
    await tester.enterText(champNom, '  Amira   Trabelsi ');
    await appuyer(tester, find.text('Enregistrer'));
    expect(planning.actions, ['nom Amira Trabelsi']);
    expect(find.text('Mes infos'), findsNothing);
    expect(find.text('Infos enregistrées.'), findsOneWidget);
    expect(find.text('Amira Trabelsi'), findsOneWidget);
  });

  testWidgets('nom vide : message, rien n\'est envoyé', (tester) async {
    await ouvrirMesInfos(tester);
    await tester.enterText(champNom, '   ');
    await appuyer(tester, find.text('Enregistrer'));
    expect(find.text('Indiquez votre nom.'), findsOneWidget);
    expect(planning.actions, isEmpty);
  });

  testWidgets('nom inchangé : retour sans envoi ni message', (tester) async {
    await ouvrirMesInfos(tester);
    await appuyer(tester, find.text('Enregistrer'));
    expect(planning.actions, isEmpty);
    expect(find.text('Mes infos'), findsNothing);
    expect(find.text('Infos enregistrées.'), findsNothing);
  });

  testWidgets('refus de la base : message, on reste sur l\'écran', (
    tester,
  ) async {
    planning.erreurAction = const ErreurSalon(
      'Action non autorisée avec ce compte.',
    );
    await ouvrirMesInfos(tester);
    await tester.enterText(champNom, 'Amira Trabelsi');
    await appuyer(tester, find.text('Enregistrer'));
    expect(find.text('Action non autorisée avec ce compte.'), findsOneWidget);
    expect(find.text('Mes infos'), findsOneWidget);
  });

  testWidgets('accueil : relu au retour sur l\'onglet (« Bonjour »)', (
    tester,
  ) async {
    Widget accueil(bool actif) => application(
      EcranAujourdhui(planning: planning, gerant: false, actif: actif),
    );
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(accueil(true));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Amira'), findsOneWidget);

    planning.nom = 'Nadia Trabelsi';
    await tester.pumpWidget(accueil(false));
    await tester.pumpAndSettle();
    await tester.pumpWidget(accueil(true));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour Nadia'), findsOneWidget);
  });
}
