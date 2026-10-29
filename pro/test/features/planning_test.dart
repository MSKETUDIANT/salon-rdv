import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/ecran_planning_equipe.dart';
import 'package:salon_pro/features/planning/elements_planning.dart';
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
      expect(find.text('1 rendez-vous · 30 min'), findsOneWidget);
      expect(
        find.bySemanticsLabel('09:00, Salma, Coupe, À clôturer'),
        findsOneWidget,
      );
      expect(find.textContaining('Karim'), findsNothing);
      expect(find.text('Absent · Formation'), findsOneWidget);

      // Un bouton par rendez-vous, activable par TalkBack (action d'appui).
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('09:00, Salma, Coupe, À clôturer'),
        ),
        matchesSemantics(
          label: '09:00, Salma, Coupe, À clôturer',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await appuyer(
        tester,
        find.bySemanticsLabel('09:00, Salma, Coupe, À clôturer'),
      );
      expect(find.text('Rendez-vous'), findsOneWidget);
      expect(find.text('+216 20 000 000'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text('09:00 – 09:30'), findsOneWidget);
      // La fiche dit l'état, comme la frise (#64).
      expect(find.text('À clôturer'), findsWidgets);
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
        find.bySemanticsLabel('11:00, Nour, Brushing, À venir'),
        findsOneWidget,
      );
    });

    testWidgets('semaine : plages du jour triées par heure de début', (
      tester,
    ) async {
      // Vendredi en horaire coupé, plage de l'après-midi renvoyée d'abord.
      planning.plages = [
        ...planning.plages,
        const PlageCoiffeur(
          coiffeurId: 'c1',
          plage: Plage(
            id: 'h5',
            jour: 5,
            debut: TimeOfDay(hour: 14, minute: 0),
            fin: TimeOfDay(hour: 19, minute: 0),
          ),
        ),
        const PlageCoiffeur(
          coiffeurId: 'c1',
          plage: Plage(
            id: 'h4',
            jour: 5,
            debut: TimeOfDay(hour: 9, minute: 0),
            fin: TimeOfDay(hour: 13, minute: 0),
          ),
        ),
      ];
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, find.text('Semaine'));
      expect(
        find.text('Aucun rendez-vous · 09:00–13:00, 14:00–19:00'),
        findsOneWidget,
      );
    });

    testWidgets('jour de repos : le message seul, sans grille (#79)', (
      tester,
    ) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      expect(find.byType(ColonneJour), findsOneWidget);
      await appuyer(tester, find.byTooltip('Jour suivant'));
      expect(
        find.text('Aucun rendez-vous · ne travaille pas ce jour-là'),
        findsOneWidget,
      );
      expect(find.byType(ColonneJour), findsNothing);
      expect(find.byType(AxeHeures), findsNothing);
    });

    testWidgets('tirer vers le bas relit le planning (#79)', (tester) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      expect(find.byTooltip('Actualiser'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
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
      expect(find.text('1 rendez-vous · 30 min'), findsOneWidget);
    });
  });

  group('Planning de l\'équipe (BF-G5)', () {
    testWidgets(
      'un coiffeur à la fois, choisi par pastille ; blocs avec leur état (#64)',
      (tester) async {
        await ouvrir(tester, EcranPlanningEquipe(planning: planning));
        expect(planning.appels, ['2030-1-7..2030-1-7 tous']);
        expect(find.widgetWithText(ChoiceChip, 'Amira'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Youssef'), findsOneWidget);
        // Résumé du coiffeur choisi (#79) ; Amira par défaut : son
        // rendez-vous, pas celui de Youssef.
        expect(find.text('1 rendez-vous · 30 min'), findsOneWidget);
        expect(
          find.bySemanticsLabel('09:00, Salma, Coupe, À clôturer'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('Karim')), findsNothing);

        await appuyer(tester, find.widgetWithText(ChoiceChip, 'Youssef'));
        expect(
          find.bySemanticsLabel('14:00, Karim, Couleur, Terminé'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('Salma')), findsNothing);
        expect(find.text('1 rendez-vous · 45 min'), findsOneWidget);
        // Pas de nouvelle lecture : la journée est déjà chargée.
        expect(planning.appels, ['2030-1-7..2030-1-7 tous']);

        await appuyer(
          tester,
          find.bySemanticsLabel('14:00, Karim, Couleur, Terminé'),
        );
        expect(find.text('Non renseigné'), findsOneWidget);
        expect(find.text('Youssef'), findsNWidgets(2));
      },
    );

    testWidgets('jour suivant : nouvelle lecture', (tester) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, find.byTooltip('Jour suivant'));
      expect(planning.appels.last, '2030-1-8..2030-1-8 tous');
      // Mardi : jour de repos d'Amira, sans rendez-vous : le message seul,
      // sans grille ni lignes horaires (#79).
      expect(
        find.text('Aucun rendez-vous · ne travaille pas ce jour-là'),
        findsOneWidget,
      );
      expect(find.byType(ColonneJour), findsNothing);
      expect(find.byType(AxeHeures), findsNothing);
    });
  });

  group('vue du jour (#79)', () {
    Plage plage(int h1, int h2) => Plage(
      id: 'p$h1',
      jour: 1,
      debut: TimeOfDay(hour: h1, minute: 0),
      fin: TimeOfDay(hour: h2, minute: 0),
    );
    RendezVous rdv(int h, int m, int duree) => RendezVous(
      id: 'r$h$m',
      coiffeurId: 'c1',
      debut: DateTime(2030, 1, 7, h, m),
      fin: DateTime(2030, 1, 7, h, m).add(Duration(minutes: duree)),
      statut: StatutRendezVous.confirmee,
      prestation: 'Coupe',
      dureeMinutes: duree,
      clientNom: 'Salma',
      prix: 20,
    );
    final lundi = DateTime(2030, 1, 7);

    test('heures affichées : seulement les horaires du coiffeur', () {
      final donnees = DonneesPlanning(
        rendezVous: const [],
        absences: const [],
        plages: [
          PlageCoiffeur(coiffeurId: 'c1', plage: plage(10, 13)),
          PlageCoiffeur(coiffeurId: 'c1', plage: plage(14, 17)),
        ],
      );
      expect(fenetreDuJour(donnees, ['c1'], lundi), (10 * 60, 17 * 60));
    });

    test('heures affichées : élargies à un rendez-vous hors horaires', () {
      final donnees = DonneesPlanning(
        rendezVous: [rdv(17, 30, 45)],
        absences: const [],
        plages: [PlageCoiffeur(coiffeurId: 'c1', plage: plage(10, 13))],
      );
      expect(fenetreDuJour(donnees, ['c1'], lundi), (10 * 60, 19 * 60));
    });

    test('résumé : nombre de rendez-vous et durée totale', () {
      expect(resumeJournee(const []), 'Aucun rendez-vous');
      expect(resumeJournee([rdv(9, 0, 30)]), '1 rendez-vous · 30 min');
      expect(
        resumeJournee([rdv(9, 0, 30), rdv(10, 0, 45), rdv(11, 0, 60)]),
        '3 rendez-vous · 2 h 15',
      );
    });
  });

  test('téléphone : format tunisien, sinon + et les chiffres', () {
    expect(formatTelephone('21620000000'), '+216 20 000 000');
    expect(formatTelephone('33612345678'), '+33612345678');
  });
}
