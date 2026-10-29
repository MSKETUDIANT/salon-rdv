import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/ecran_planning_equipe.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';

// Clôture et encaissement depuis la fiche d'un rendez-vous (#11, BF-K3,
// BF-K4, BF-G4). Les droits et la règle « commencé » sont vérifiés par la
// base (supabase/tests/cloture_encaissement.test.sql) ; ici, l'affichage.
// Dans la doublure, il est lundi 7 janvier 2030, 10:00 : r1 (09:00) a
// commencé, r3 (mercredi 11:00) est à venir, r2 (Youssef) est terminé.

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

final r1 = find.bySemanticsLabel(RegExp(r'^09:00, Salma'));
final r2 = find.bySemanticsLabel(RegExp(r'^14:00, Karim'));
final boutonTermine = find.widgetWithText(FilledButton, 'Terminé');
// Planning de l'équipe : un coiffeur à la fois (#64).
final youssef = find.widgetWithText(ChoiceChip, 'Youssef');

// Remplace r2 (Youssef, terminé) par la même ligne avec un montant encaissé.
void encaisserR2(double montant) {
  planning.rendezVous = [
    for (final r in planning.rendezVous)
      r.id == 'r2'
          ? RendezVous(
              id: r.id,
              coiffeurId: r.coiffeurId,
              debut: r.debut,
              fin: r.fin,
              statut: r.statut,
              prestation: r.prestation,
              dureeMinutes: r.dureeMinutes,
              clientNom: r.clientNom,
              prix: r.prix,
              montantEncaisse: montant,
            )
          : r,
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => planning = FauxPlanning());

  group('Coiffeur : clôture de ses rendez-vous (BF-K3, BF-K4)', () {
    testWidgets('commencé : « Terminé » après confirmation, puis relecture', (
      tester,
    ) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, r1);
      expect(boutonTermine, findsOneWidget);
      expect(find.text('Client absent'), findsOneWidget);
      expect(find.text('Encaisser'), findsNothing);
      expect(find.text('Encaissé'), findsNothing);

      await appuyer(tester, boutonTermine);
      expect(find.text('Marquer terminé ?'), findsOneWidget);
      expect(
        find.text('Rendez-vous de 09:00 avec Salma. Ce choix est définitif.'),
        findsOneWidget,
      );
      await appuyer(tester, find.text('Marquer terminé'));

      expect(planning.actions, ['r1 terminee']);
      expect(find.text('Rendez-vous de 09:00 marqué terminé.'), findsOneWidget);
      expect(find.text('Rendez-vous'), findsNothing);
      expect(planning.appels, [
        '2030-1-7..2030-1-7 c1',
        '2030-1-7..2030-1-7 c1',
      ]);
    });

    testWidgets('« Annuler » dans la confirmation : rien n\'est enregistré', (
      tester,
    ) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, r1);
      await appuyer(tester, find.text('Client absent'));
      expect(find.text('Client absent ?'), findsOneWidget);
      await appuyer(tester, find.text('Annuler'));
      expect(planning.actions, isEmpty);
      expect(find.text('Rendez-vous'), findsOneWidget);
    });

    testWidgets('« Client absent » après confirmation', (tester) async {
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, r1);
      await appuyer(tester, find.text('Client absent'));
      await appuyer(tester, find.text('Marquer absent'));
      expect(planning.actions, ['r1 absent']);
      expect(
        find.text('Client du rendez-vous de 09:00 marqué absent.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'à venir : pas de bouton, heure à partir de laquelle clôturer',
      (tester) async {
        await ouvrir(tester, EcranMonPlanning(planning: planning));
        // Mercredi dans la bande des jours (#98).
        await appuyer(tester, find.bySemanticsLabel('Mercredi 9 janvier'));
        await appuyer(tester, find.bySemanticsLabel(RegExp(r'^11:00, Nour')));
        expect(
          find.text('Clôture possible à partir du mercredi 9 janvier, 11:00.'),
          findsOneWidget,
        );
        expect(boutonTermine, findsNothing);
        expect(find.text('Client absent'), findsNothing);
      },
    );

    testWidgets('refus de la base : message dans la fiche, qui reste ouverte', (
      tester,
    ) async {
      planning.erreurAction = const ErreurSalon(
        'Ce rendez-vous n\'a pas encore commencé : clôture impossible.',
      );
      await ouvrir(tester, EcranMonPlanning(planning: planning));
      await appuyer(tester, r1);
      await appuyer(tester, boutonTermine);
      await appuyer(tester, find.text('Marquer terminé'));
      expect(
        find.text(
          'Ce rendez-vous n\'a pas encore commencé : clôture impossible.',
        ),
        findsOneWidget,
      );
      expect(find.text('Rendez-vous'), findsOneWidget);
      expect(planning.actions, isEmpty);
    });
  });

  group('Gérant : clôture pour un coiffeur, encaissement (BF-G4)', () {
    testWidgets('clôture le rendez-vous commencé d\'un coiffeur', (
      tester,
    ) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, r1);
      expect(find.text('Amira'), findsWidgets);
      await appuyer(tester, boutonTermine);
      await appuyer(tester, find.text('Marquer terminé'));
      expect(planning.actions, ['r1 terminee']);
    });

    testWidgets('terminé non encaissé : montant prérempli, modifiable', (
      tester,
    ) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, youssef);
      await appuyer(tester, r2);
      expect(find.text('Pas encore'), findsOneWidget);
      expect(boutonTermine, findsNothing);

      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      expect(find.text('Prix de la prestation : 80 DT'), findsOneWidget);
      expect(find.widgetWithText(TextField, '80'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '75,5');
      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      expect(planning.actions, ['r2 encaisse 75.5']);
      expect(find.text('Encaissement enregistré.'), findsOneWidget);
      expect(planning.appels.last, '2030-1-7..2030-1-7 tous');
    });

    testWidgets('montant invalide : message, rien n\'est enregistré', (
      tester,
    ) async {
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, youssef);
      await appuyer(tester, r2);
      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      await tester.enterText(find.byType(TextField), '-3');
      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      expect(
        find.text('Indiquez un montant positif, par exemple 35 ou 10,500.'),
        findsOneWidget,
      );
      expect(planning.actions, isEmpty);
    });

    testWidgets('refus de la base : message dans le formulaire', (
      tester,
    ) async {
      planning.erreurAction = const ErreurSalon(
        'Ce rendez-vous est déjà encaissé.',
      );
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, youssef);
      await appuyer(tester, r2);
      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      await appuyer(tester, find.widgetWithText(FilledButton, 'Encaisser'));
      expect(find.text('Ce rendez-vous est déjà encaissé.'), findsOneWidget);
    });

    testWidgets('déjà encaissé : montant affiché, correction du montant', (
      tester,
    ) async {
      encaisserR2(80);
      await ouvrir(tester, EcranPlanningEquipe(planning: planning));
      await appuyer(tester, youssef);
      await appuyer(tester, r2);
      expect(find.text('80 DT'), findsNWidgets(2)); // prix et encaissé
      expect(find.widgetWithText(FilledButton, 'Encaisser'), findsNothing);

      await appuyer(tester, find.text('Corriger le montant'));
      expect(
        find.text(
          'Montant enregistré : 80 DT. L\'ancien montant ne sera pas conservé.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '78');
      await appuyer(tester, find.text('Enregistrer la correction'));
      expect(planning.actions, ['r2 corrige 78.0']);
      expect(find.text('Montant corrigé.'), findsOneWidget);
    });
  });
}
