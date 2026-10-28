import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../doublures/faux_planning.dart';

// Onglet « Aujourd'hui » (#64) : titre, compteurs, prochain rendez-vous,
// encaissé du gérant, gestes de clôture différée.

late FauxPlanning planning;
final vibrations = <String>[];

RendezVous rdv(
  String id,
  String coiffeur,
  int h,
  int m,
  int duree,
  StatutRendezVous statut,
  String client, {
  double? montant,
}) {
  final debut = DateTime(2030, 1, 7, h, m);
  return RendezVous(
    id: id,
    coiffeurId: coiffeur,
    debut: debut,
    fin: debut.add(Duration(minutes: duree)),
    statut: statut,
    prestation: 'Coupe',
    dureeMinutes: duree,
    clientNom: client,
    prix: 20,
    montantEncaisse: montant,
  );
}

// Lundi 7 janvier, 10:00. Amira (c1) : un terminé, un absent, un à clôturer,
// un en cours, un à venir ; Youssef (c2) : un terminé encaissé, un à venir.
void journee() {
  planning.rendezVous = [
    rdv('t', 'c1', 8, 0, 30, StatutRendezVous.terminee, 'Inès', montant: 20),
    rdv('a', 'c1', 8, 30, 30, StatutRendezVous.absent, 'Yasmine'),
    rdv('c', 'c1', 9, 0, 30, StatutRendezVous.confirmee, 'Salma'),
    rdv('e', 'c1', 9, 45, 45, StatutRendezVous.confirmee, 'Nour'),
    rdv('v', 'c1', 14, 0, 45, StatutRendezVous.confirmee, 'Rania'),
    rdv('y1', 'c2', 8, 0, 30, StatutRendezVous.terminee, 'Karim', montant: 25),
    rdv('y2', 'c2', 11, 30, 30, StatutRendezVous.confirmee, 'Sami'),
  ];
}

Future<void> ouvrir(
  WidgetTester tester, {
  bool gerant = false,
  bool actif = true,
  bool sansAnimations = true,
  bool petitEcran = false,
}) async {
  // Petit écran : 360 × 640, la liste du jour sous le pli.
  tester.view.physicalSize = petitEcran
      ? const Size(720, 1280)
      : const Size(1080, 5400);
  tester.view.devicePixelRatio = petitEcran ? 2 : 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: MediaQuery(
        data: MediaQueryData(
          size: petitEcran ? const Size(360, 640) : const Size(360, 1800),
          disableAnimations: sansAnimations,
        ),
        child: EcranAujourdhui(
          planning: planning,
          gerant: gerant,
          actif: actif,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final salma = find.bySemanticsLabel(RegExp(r'^09:00, Salma'));

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() {
    planning = FauxPlanning();
    journee();
    SharedPreferences.setMockInitialValues({});
    reinitialiserIndice();
    vibrations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (appel) async {
          if (appel.method == 'HapticFeedback.vibrate') {
            vibrations.add(appel.arguments as String);
          }
          return null;
        });
  });

  testWidgets(
    'coiffeur : titre, total en cours compris, chiffres qui tombent juste',
    (tester) async {
      await ouvrir(tester);
      expect(planning.appels, ['2030-1-7..2030-1-7 c1']);
      expect(find.text('Lundi 7 janvier · Espace coiffeur'), findsOneWidget);
      // 5 rendez-vous d'Amira, celui en cours compris.
      expect(
        find.text("Bonjour Amira,\n5 clients aujourd'hui"),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('1 terminé'), findsOneWidget);
      expect(find.bySemanticsLabel('1 absent'), findsOneWidget);
      // À clôturer, en cours et à venir : 1 + 1 + 1.
      expect(find.bySemanticsLabel('3 restants'), findsOneWidget);
      expect(find.text('Encaissé aujourd\'hui'), findsNothing);

      expect(
        find.bySemanticsLabel('En cours : 09:45 – 10:30 · Nour, Coupe'),
        findsOneWidget,
      );
      expect(find.text('Prochain rendez-vous'), findsOneWidget);
      expect(find.text('14:00'), findsWidgets);
      expect(find.text('dans 4 h'), findsOneWidget);
      expect(find.text('Rania'), findsWidgets);
    },
  );

  testWidgets('gérant : tout le salon, encaissé du jour et à encaisser', (
    tester,
  ) async {
    planning.rendezVous = [
      ...planning.rendezVous,
      rdv('y3', 'c2', 9, 0, 30, StatutRendezVous.terminee, 'Ali'),
    ];
    await ouvrir(tester, gerant: true);
    expect(planning.appels, ['2030-1-7..2030-1-7 tous']);
    expect(find.text("Bonjour Amira,\n8 clients aujourd'hui"), findsOneWidget);
    expect(find.text('Encaissé aujourd\'hui'), findsOneWidget);
    expect(find.text('45 DT'), findsOneWidget);
    expect(find.text('1 à encaisser'), findsOneWidget);
    expect(find.bySemanticsLabel('3 terminés'), findsOneWidget);
    expect(find.text('Prochain rendez-vous du salon'), findsOneWidget);
    expect(find.text('Coupe · avec Youssef · 30 min · 20 DT'), findsOneWidget);
    expect(
      find.bySemanticsLabel('11:30, Sami, Coupe, Youssef, À venir'),
      findsOneWidget,
    );
  });

  testWidgets(
    'glisser à droite : « Terminé » affiché, vibration, enregistré au bout de 5 s',
    (tester) async {
      await ouvrir(tester);
      await tester.drag(salma, const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(vibrations, contains('HapticFeedbackType.mediumImpact'));
      expect(find.text('Salma, 09:00 : terminé.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Annuler'), findsOneWidget);
      expect(
        find.bySemanticsLabel('09:00, Salma, Coupe, Terminé'),
        findsOneWidget,
      );
      expect(planning.actions, isEmpty);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(planning.actions, ['c terminee']);
      expect(planning.appels.length, 2); // relu après l'enregistrement
    },
  );

  testWidgets('glisser à gauche puis « Annuler » : rien n\'est enregistré', (
    tester,
  ) async {
    await ouvrir(tester);
    await tester.drag(salma, const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(find.text('Salma, 09:00 : client absent.'), findsOneWidget);
    expect(
      find.bySemanticsLabel('09:00, Salma, Coupe, Absent'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(SnackBarAction, 'Annuler'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('09:00, Salma, Coupe, À clôturer'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(planning.actions, isEmpty);
  });

  testWidgets('quitter l\'onglet pendant le délai : enregistré tout de suite', (
    tester,
  ) async {
    await ouvrir(tester);
    await tester.drag(salma, const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(planning.actions, isEmpty);

    await ouvrir(tester, actif: false);
    expect(planning.actions, ['c terminee']);
  });

  testWidgets('l\'app passe en arrière-plan : enregistré tout de suite', (
    tester,
  ) async {
    await ouvrir(tester);
    await tester.drag(salma, const Offset(-260, 0));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(planning.actions, ['c absent']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('un rendez-vous à venir ne se glisse pas', (tester) async {
    await ouvrir(tester);
    final rania = find.bySemanticsLabel(RegExp(r'^14:00, Rania'));
    await tester.drag(rania, const Offset(260, 0));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(planning.actions, isEmpty);
  });

  testWidgets(
    'TalkBack : « Terminé » et « Client absent » en actions du nœud',
    (tester) async {
      final semantique = tester.ensureSemantics();
      await ouvrir(tester);
      final donnees = tester.getSemantics(salma).getSemanticsData();
      final actions = [
        for (final id in donnees.customSemanticsActionIds ?? <int>[])
          CustomSemanticsAction.getAction(id)!.label,
      ];
      expect(actions, containsAll(['Terminé', 'Client absent']));
      final rania = tester
          .getSemantics(find.bySemanticsLabel(RegExp(r'^14:00, Rania')))
          .getSemanticsData();
      expect(rania.customSemanticsActionIds ?? [], isEmpty);
      semantique.dispose();
    },
  );

  testWidgets(
    'indice au premier usage : la première carte glissable bouge une fois, retenu pour toujours',
    (tester) async {
      await ouvrir(tester, sansAnimations: false);
      Offset decalage() => tester
          .widgetList<Transform>(
            find.descendant(of: salma, matching: find.byType(Transform)),
          )
          .map((t) => Offset(t.transform.getTranslation().x, 0))
          .firstWhere((o) => o.dx != 0, orElse: () => Offset.zero);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(decalage().dx, greaterThan(0));
      await tester.pumpAndSettle();
      expect(decalage(), Offset.zero);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(cleIndiceGestes), isTrue);

      // Pas d'indice à la relecture.
      await ouvrir(tester, sansAnimations: false, actif: false);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(decalage(), Offset.zero);
    },
  );

  testWidgets(
    "indice déjà vu sur cet appareil : pas d'indice au lancement suivant",
    (tester) async {
      // Nouveau lancement de l'app : préférences relues.
      SharedPreferences.setMockInitialValues({cleIndiceGestes: true});
      reinitialiserIndice();
      await ouvrir(tester, sansAnimations: false);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(
        find.descendant(of: salma, matching: find.byType(Transform)),
        findsNothing,
      );
    },
  );

  testWidgets('moins d\'animations demandées : pas d\'indice', (tester) async {
    await ouvrir(tester);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      find.descendant(of: salma, matching: find.byType(Transform)),
      findsNothing,
    );
  });

  testWidgets(
    "petit écran : l'indice attend que la carte soit visible, puis est retenu",
    (tester) async {
      await ouvrir(tester, sansAnimations: false, petitEcran: true);
      bool bouge() => find
          .descendant(of: salma, matching: find.byType(Transform))
          .evaluate()
          .isNotEmpty;
      // Liste sous le pli : rien ne bouge, rien n'est retenu.
      await tester.pump(const Duration(seconds: 2));
      expect(bouge(), isFalse);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool(cleIndiceGestes), isNull);

      // La carte arrive à l'écran : l'indice part, puis il est retenu.
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      // Pas à pas : l'indice part 600 ms après l'arrivée de la carte.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 500));
      expect(bouge(), isTrue);
      await tester.pumpAndSettle();
      expect(preferences.getBool(cleIndiceGestes), isTrue);
    },
  );

  testWidgets(
    "enregistrement en quittant l'onglet : le message « Annuler » disparaît",
    (tester) async {
      await ouvrir(tester);
      await tester.drag(salma, const Offset(260, 0));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SnackBarAction, 'Annuler'), findsOneWidget);

      await ouvrir(tester, actif: false);
      expect(planning.actions, ['c terminee']);
      expect(find.widgetWithText(SnackBarAction, 'Annuler'), findsNothing);
    },
  );

  testWidgets(
    'après une clôture, relecture sans chargement : la liste garde sa place',
    (tester) async {
      await ouvrir(tester, petitEcran: true);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final avant = position.pixels;
      expect(avant, greaterThan(0));

      await tester.drag(salma, const Offset(260, 0));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(planning.actions, ['c terminee']);
      expect(planning.appels.length, 2);
      expect(position.pixels, avant);
    },
  );
}
