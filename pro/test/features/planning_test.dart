import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/ecran_planning_equipe.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:salon_pro/ui/format.dart';

import '../doublures/faux_planning.dart';

// Plannings (#10). Le filtrage des droits est fait par la base (fonction
// planning(), supabase/tests/planning.test.sql) ; ici, l'affichage.

late FauxPlanning planning;

Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
  tester.view.physicalSize = const Size(1080, 5400);
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

  group('Mon planning (BF-K1, BF-K2)', () {
    testWidgets('jour : ses rendez-vous seulement, absence, puis le détail', (
      tester,
    ) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      expect(planning.appels, ['2030-1-7..2030-1-7 c1']);
      expect(find.text('Lundi 7 janvier'), findsOneWidget);
      expect(find.text('1 rendez-vous'), findsOneWidget);
      expect(
        find.bySemanticsLabel('09:00, Salma, Coupe, Confirmé'),
        findsOneWidget,
      );
      expect(find.textContaining('Karim'), findsNothing);
      expect(find.text('Absent · Formation'), findsOneWidget);

      // Un bouton par rendez-vous, activable par TalkBack (action d'appui).
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('09:00, Salma, Coupe, Confirmé'),
        ),
        matchesSemantics(
          label: '09:00, Salma, Coupe, Confirmé',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await appuyer(
        tester,
        find.bySemanticsLabel('09:00, Salma, Coupe, Confirmé'),
      );
      expect(find.text('Rendez-vous'), findsOneWidget);
      expect(find.text('+216 20 000 000'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('09:00 – 09:30'), findsOneWidget);
      expect(find.text('Confirmé'), findsOneWidget);
    });

    testWidgets('jour suivant, puis retour à aujourd\'hui', (tester) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      expect(find.text('Revenir à aujourd\'hui'), findsNothing);
      await appuyer(tester, find.byTooltip('Jour suivant'));
      expect(find.text('Mardi 8 janvier'), findsOneWidget);
      expect(
        find.text('Aucun rendez-vous · ne travaille pas ce jour-là'),
        findsOneWidget,
      );
      expect(planning.appels.last, '2030-1-8..2030-1-8 c1');

      await appuyer(tester, find.text('Revenir à aujourd\'hui'));
      expect(find.text('Lundi 7 janvier'), findsOneWidget);
    });

    testWidgets('semaine : du lundi au dimanche, un jour ouvre la vue Jour', (
      tester,
    ) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, find.text('Semaine'));
      expect(planning.appels.last, '2030-1-7..2030-1-13 c1');
      expect(find.text('Semaine du lundi 7 janvier'), findsOneWidget);
      expect(find.text('09:00  Salma · Coupe'), findsOneWidget);
      expect(find.text('11:00  Nour · Brushing'), findsOneWidget);
      expect(find.text('Absent 15:00–16:00 · Formation'), findsOneWidget);
      expect(find.text('Ne travaille pas'), findsNWidgets(5));

      await appuyer(tester, find.text('Mercredi 9 janvier'));
      expect(planning.appels.last, '2030-1-9..2030-1-9 c1');
      expect(
        find.bySemanticsLabel('11:00, Nour, Brushing, Confirmé'),
        findsOneWidget,
      );
    });

    testWidgets('« Actualiser » relit le planning', (tester) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, find.byTooltip('Actualiser'));
      expect(planning.appels, [
        '2030-1-7..2030-1-7 c1',
        '2030-1-7..2030-1-7 c1',
      ]);
    });

    testWidgets('refus de la base : message et « Réessayer »', (tester) async {
      planning.erreur = const ErreurSalon(
        'Planning réservé à l\'équipe du salon.',
      );
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      expect(
        find.text('Planning réservé à l\'équipe du salon.'),
        findsOneWidget,
      );
      planning.erreur = null;
      await appuyer(tester, find.text('Réessayer'));
      expect(find.text('1 rendez-vous'), findsOneWidget);
    });
  });

  group('Planning de l\'équipe (BF-G5)', () {
    testWidgets('une colonne par coiffeur, tous les rendez-vous du jour', (
      tester,
    ) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      expect(planning.appels, ['2030-1-7..2030-1-7 tous']);
      expect(find.text('Amira'), findsOneWidget);
      expect(find.text('Youssef'), findsOneWidget);
      expect(find.text('2 coiffeurs · 2 rendez-vous'), findsOneWidget);
      expect(
        find.bySemanticsLabel('09:00, Salma, Coupe, Confirmé'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('14:00, Karim, Couleur, Terminé'),
        findsOneWidget,
      );

      await appuyer(
        tester,
        find.bySemanticsLabel('14:00, Karim, Couleur, Terminé'),
      );
      expect(find.text('Non renseigné'), findsOneWidget);
      expect(find.text('Youssef'), findsNWidgets(2));
    });

    testWidgets('jour suivant : nouvelle lecture', (tester) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, find.byTooltip('Jour suivant'));
      expect(planning.appels.last, '2030-1-8..2030-1-8 tous');
      expect(find.text('2 coiffeurs · aucun rendez-vous'), findsOneWidget);
    });
  });

  test('téléphone : format tunisien, sinon + et les chiffres', () {
    expect(formatTelephone('21620000000'), '+216 20 000 000');
    expect(formatTelephone('33612345678'), '+33612345678');
  });
}
