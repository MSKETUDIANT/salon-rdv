import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/features/gerant/ecran_delai_annulation.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:salon_pro/ui/format.dart';

import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Délai minimum d'annulation (#118, options 1A et 2a) : ligne « Annulation »
// de l'onglet Salon, écran de choix. Droits, bornes et effet sur
// l'annulation : delai_annulation.test.sql.

late FauxSalon salon;

Future<void> monter(WidgetTester tester, Widget ecran) async {
  tester.view.physicalSize = const Size(1080, 3200);
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

// Ligne de choix, par son libellé (lu par TalkBack).
Finder choix(String libelle) => find.bySemanticsLabel(libelle);

void attendreChoisi(WidgetTester tester, String libelle, bool choisi) => expect(
  tester.getSemantics(choix(libelle)),
  isSemantics(isSelected: choisi),
  reason: libelle,
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => salon = FauxSalon());

  test('libellés du délai', () {
    expect(formatDelaiAnnulation(0), "Jusqu'au rendez-vous");
    expect(formatDelaiAnnulation(120), '2 h avant');
    expect(formatDelaiAnnulation(30), '30 min avant');
    expect(formatDelaiCourt(0), 'Sans délai');
    expect(formatDelaiCourt(1440), '24 h avant');
  });

  testWidgets('onglet Salon : « Annulation », puis le délai choisi', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    await monter(
      tester,
      OngletSalonGerant(salon: salon, planning: FauxPlanning()),
    );
    await appuyer(tester, find.bySemanticsLabel('Annulation, Sans délai'));
    expect(find.text("Jusqu'au rendez-vous"), findsOneWidget);

    await appuyer(tester, choix('2 h avant'));
    expect(salon.actionsDelai, ['délai 120']);
    await appuyer(tester, find.byTooltip('Retour'));
    expect(find.bySemanticsLabel('Annulation, 2 h avant'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('écran : coche sur le délai actuel, un toucher enregistre', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    salon.delaiAnnulation = 1440;
    await monter(tester, EcranDelaiAnnulation(salon: salon));
    for (final libelle in [
      "Jusqu'au rendez-vous",
      '1 h avant',
      '2 h avant',
      '12 h avant',
      '24 h avant',
      '48 h avant',
    ]) {
      expect(choix(libelle), findsOneWidget, reason: libelle);
    }
    attendreChoisi(tester, '24 h avant', true);
    attendreChoisi(tester, '2 h avant', false);

    // Toucher le choix actuel : rien n'est envoyé.
    await appuyer(tester, choix('24 h avant'));
    expect(salon.actionsDelai, isEmpty);

    await appuyer(tester, choix("Jusqu'au rendez-vous"));
    expect(salon.actionsDelai, ['délai 0']);
    expect(find.text("Délai d'annulation enregistré."), findsOneWidget);
    attendreChoisi(tester, "Jusqu'au rendez-vous", true);
    semantique.dispose();
  });

  testWidgets('délai réglé hors de la liste : affiché quand même', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    salon.delaiAnnulation = 30;
    await monter(tester, EcranDelaiAnnulation(salon: salon));
    attendreChoisi(tester, '30 min avant', true);
    semantique.dispose();
  });

  testWidgets('refus de la base : message, le délai ne change pas', (
    tester,
  ) async {
    await monter(tester, EcranDelaiAnnulation(salon: salon));
    salon.prochaineErreur = const ErreurSalon(
      'Action non autorisée avec ce compte.',
    );
    await appuyer(tester, find.text('2 h avant'));
    expect(find.text('Action non autorisée avec ce compte.'), findsOneWidget);
    expect(salon.delaiAnnulation, 0);
  });
}
