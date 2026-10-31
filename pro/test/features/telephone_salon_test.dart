import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/features/gerant/ecran_telephone_salon.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Téléphone du salon (#129, option A) : ligne « Téléphone » de l'onglet
// Salon, écran de saisie. Droits et format : horaires_telephone_salon.test.sql.

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

Finder champ() => find.byType(TextField);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => salon = FauxSalon());

  testWidgets(
    'onglet Salon : « Téléphone », saisie, numéro affiché au retour',
    (tester) async {
      final semantique = tester.ensureSemantics();
      await monter(
        tester,
        OngletSalonGerant(salon: salon, planning: FauxPlanning()),
      );
      await appuyer(tester, find.bySemanticsLabel('Téléphone, Aucun'));
      expect(find.byType(EcranTelephoneSalon), findsOneWidget);

      await tester.enterText(champ(), ' 71  234 567 ');
      await appuyer(tester, find.text('Enregistrer'));
      expect(salon.actionsTelephone, ['téléphone 71 234 567']);
      expect(find.byType(EcranTelephoneSalon), findsNothing);
      expect(find.bySemanticsLabel('Téléphone, 71 234 567'), findsOneWidget);
      // Aussi dans l'en-tête du salon, sous l'adresse.
      expect(find.text('71 234 567'), findsNWidgets(2));
      semantique.dispose();
    },
  );

  testWidgets('numéro refusé : message sous le champ, écran gardé', (
    tester,
  ) async {
    await monter(tester, EcranTelephoneSalon(salon: salon, telephone: null));
    await tester.enterText(champ(), '12 34');
    await appuyer(tester, find.text('Enregistrer'));
    expect(find.text(messageTelephoneInvalide), findsOneWidget);
    expect(salon.actionsTelephone, isEmpty);
    expect(find.byType(EcranTelephoneSalon), findsOneWidget);
  });

  testWidgets('champ vidé : le numéro est retiré', (tester) async {
    salon.telephone = '71 234 567';
    await monter(
      tester,
      EcranTelephoneSalon(salon: salon, telephone: '71 234 567'),
    );
    await tester.enterText(champ(), '');
    await appuyer(tester, find.text('Enregistrer'));
    expect(salon.actionsTelephone, ['téléphone retiré']);
    expect(salon.telephone, isNull);
  });

  testWidgets('erreur réseau : message au-dessus du bouton', (tester) async {
    salon.prochaineErreur = const ErreurSalon('Pas de connexion.');
    await monter(tester, EcranTelephoneSalon(salon: salon, telephone: null));
    await tester.enterText(champ(), '71 234 567');
    await appuyer(tester, find.text('Enregistrer'));
    expect(find.text('Pas de connexion.'), findsOneWidget);
    expect(find.byType(EcranTelephoneSalon), findsOneWidget);
  });

  testWidgets('numéro inchangé : retour sans enregistrer', (tester) async {
    await monter(
      tester,
      EcranTelephoneSalon(salon: salon, telephone: '71 234 567'),
    );
    await appuyer(tester, find.text('Enregistrer'));
    expect(salon.actionsTelephone, isEmpty);
  });
}
