import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/features/gerant/ecran_photo_salon.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:salon_pro/ui/photo_salon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Photo du salon (#105, options 1A et 2a) : ligne de l'onglet Salon du
// gérant, écran de la photo, bandeau de l'accueil. Droits et espace de
// stockage : photo_salon.test.sql.

late FauxSalon salon;
late FauxPlanning planning;

// Sources demandées au sélecteur, et image qu'il renvoie (null : abandon).
final sources = <ImageSource>[];
PhotoChoisie? choix;
bool selecteurEnPanne = false;

Future<PhotoChoisie?> choisir(ImageSource source) async {
  sources.add(source);
  if (selecteurEnPanne) throw Exception('indisponible');
  return choix;
}

Future<void> monter(WidgetTester tester, Widget ecran) async {
  tester.view.physicalSize = const Size(1080, 2400);
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

Widget ecranPhoto() => EcranPhotoSalon(salon: salon, choisir: choisir);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() {
    salon = FauxSalon();
    planning = FauxPlanning();
    sources.clear();
    choix = (octets: Uint8List.fromList([1, 2, 3]), type: 'image/jpeg');
    selecteurEnPanne = false;
    SharedPreferences.setMockInitialValues({});
    reinitialiserIndice();
  });

  testWidgets('onglet Salon : « Photo du salon », par défaut puis '
      'personnalisée', (tester) async {
    await monter(tester, OngletSalonGerant(salon: salon, planning: planning));
    expect(find.bySemanticsLabel('Photo du salon, Par défaut'), findsOneWidget);
    await appuyer(tester, find.bySemanticsLabel('Photo du salon, Par défaut'));
    expect(find.text('Changer la photo'), findsOneWidget);

    salon.photo = 'https://exemple.test/p.jpg';
    await appuyer(tester, find.byTooltip('Retour'));
    expect(
      find.bySemanticsLabel('Photo du salon, Personnalisée'),
      findsOneWidget,
    );
  });

  testWidgets('changer : galerie, envoi, message, « Retirer » apparaît', (
    tester,
  ) async {
    await monter(tester, ecranPhoto());
    expect(find.textContaining('Image par défaut.'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsNothing);

    await appuyer(tester, find.text('Changer la photo'));
    await appuyer(tester, find.text('Choisir dans la galerie'));
    expect(sources, [ImageSource.gallery]);
    expect(salon.actionsPhoto, ['photo image/jpeg 3 octets']);
    expect(find.text('Photo enregistrée.'), findsOneWidget);
    expect(
      tester.widget<PhotoSalon>(find.byType(PhotoSalon)).adresse,
      salon.photo,
    );
    expect(find.text('Retirer la photo'), findsOneWidget);
  });

  testWidgets('appareil photo, puis choix abandonné : rien n\'est envoyé', (
    tester,
  ) async {
    choix = null;
    await monter(tester, ecranPhoto());
    await appuyer(tester, find.text('Changer la photo'));
    await appuyer(tester, find.text('Prendre une photo'));
    expect(sources, [ImageSource.camera]);
    expect(salon.actionsPhoto, isEmpty);
  });

  testWidgets('sélecteur indisponible : message', (tester) async {
    selecteurEnPanne = true;
    await monter(tester, ecranPhoto());
    await appuyer(tester, find.text('Changer la photo'));
    await appuyer(tester, find.text('Choisir dans la galerie'));
    expect(find.text('Galerie indisponible.'), findsOneWidget);
    expect(salon.actionsPhoto, isEmpty);
  });

  testWidgets('refus à l\'envoi : message, la photo ne change pas', (
    tester,
  ) async {
    await monter(tester, ecranPhoto());
    salon.prochaineErreur = const ErreurSalon(
      'Photo trop lourde : 5 Mo au plus.',
    );
    await appuyer(tester, find.text('Changer la photo'));
    await appuyer(tester, find.text('Choisir dans la galerie'));
    expect(find.text('Photo trop lourde : 5 Mo au plus.'), findsOneWidget);
    expect(salon.photo, isNull);
  });

  testWidgets('retirer : confirmation, puis image par défaut', (tester) async {
    salon.photo = 'https://exemple.test/p.jpg';
    await monter(tester, ecranPhoto());
    await appuyer(tester, find.text('Retirer la photo'));
    expect(find.text('Retirer la photo ?'), findsOneWidget);
    await appuyer(tester, find.widgetWithText(FilledButton, 'Retirer'));
    expect(salon.actionsPhoto, ['photo retirée']);
    expect(find.text('Photo retirée.'), findsOneWidget);
    expect(find.text('Retirer la photo'), findsNothing);
  });

  testWidgets('accueil : le bandeau reçoit la photo du salon', (tester) async {
    planning.photo = 'https://exemple.test/p.jpg';
    await monter(tester, EcranAujourdhui(planning: planning, gerant: false));
    expect(
      tester.widget<PhotoSalon>(find.byType(PhotoSalon)).adresse,
      'https://exemple.test/p.jpg',
    );
    expect(find.bySemanticsLabel('Photo du salon'), findsOneWidget);
  });

  testWidgets('accueil : sans photo lisible, l\'image par défaut', (
    tester,
  ) async {
    await monter(tester, EcranAujourdhui(planning: planning, gerant: false));
    expect(tester.widget<PhotoSalon>(find.byType(PhotoSalon)).adresse, isNull);
  });

  test('messages des refus de l\'API Storage', () {
    expect(messageErreurPhoto('413'), 'Photo trop lourde : 5 Mo au plus.');
    expect(
      messageErreurPhoto('415'),
      'Format non accepté : JPEG, PNG ou WebP.',
    );
    expect(messageErreurPhoto('403'), 'Photo réservée au gérant du salon.');
    expect(messageErreurPhoto('500'), messageErreurInconnue);
  });
}
