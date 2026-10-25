import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/gerant/ecran_coiffeur.dart';
import 'package:salon_pro/features/gerant/ecran_prestations.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_salon.dart';

// Écrans de configuration du salon (#9), avec la doublure du dépôt. Les
// refus de la base (RLS, contraintes) sont testés dans
// supabase/tests/configuration_salon.test.sql.

late FauxSalon salon;

Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
  // Écran haut : les trois sections de la fiche coiffeur tiennent sans défiler.
  tester.view.physicalSize = const Size(1080, 4000);
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

// Fait défiler jusqu'à l'élément, puis appuie dessus.
Future<void> appuyer(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

Future<void> saisir(WidgetTester tester, String libelle, String texte) async {
  await tester.enterText(
    find.bySemanticsLabel(RegExp('^$libelle')).first,
    texte,
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => salon = FauxSalon());

  group('Prestations (BF-G2)', () {
    testWidgets(
      'liste : prix, durée ; une prestation désactivée est signalée',
      (tester) async {
        await ouvrir(tester, EcranPrestations(salon: salon));
        expect(find.text('Coupe femme'), findsOneWidget);
        expect(find.text('35 DT · 45 min'), findsOneWidget);
        expect(find.text('10,500 DT · 15 min'), findsOneWidget);
        expect(
          find.text('Désactivée : plus proposée aux clients'),
          findsOneWidget,
        );
        expect(find.text('Réactiver'), findsOneWidget);
      },
    );

    testWidgets(
      'création : ce qui manque est indiqué, puis la prestation apparaît',
      (tester) async {
        await ouvrir(tester, EcranPrestations(salon: salon));
        await tester.tap(find.text('Ajouter une prestation'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Enregistrer'));
        await tester.pump();
        expect(find.text('Indiquez le nom de la prestation.'), findsOneWidget);
        expect(find.textContaining('Indiquez un prix positif'), findsOneWidget);
        expect(find.textContaining('Indiquez une durée'), findsOneWidget);
        expect(salon.journal, isEmpty);

        await saisir(tester, 'Nom', 'Brushing');
        await saisir(tester, 'Prix', '25,5');
        await saisir(tester, 'Durée', '30');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();

        expect(salon.journal, ['creer Brushing 25.5 30']);
        expect(find.text('Nouvelle prestation'), findsNothing);
        expect(find.text('25,500 DT · 30 min'), findsOneWidget);
      },
    );

    testWidgets(
      'modification : champs préremplis, durée nouvelle sans toucher aux rendez-vous',
      (tester) async {
        await ouvrir(tester, EcranPrestations(salon: salon));
        await tester.tap(find.bySemanticsLabel('Modifier Barbe'));
        await tester.pumpAndSettle();
        expect(find.text('10,500'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(
          find.textContaining('gardent leur heure de fin'),
          findsOneWidget,
        );

        await saisir(tester, 'Prix', '12');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(salon.journal, ['modifier p2 Barbe 12.0 15']);
        expect(find.text('12 DT · 15 min'), findsOneWidget);
      },
    );

    testWidgets('désactiver puis réactiver, sans suppression', (tester) async {
      await ouvrir(tester, EcranPrestations(salon: salon));
      await tester.tap(find.bySemanticsLabel('Désactiver Coupe femme'));
      await tester.pumpAndSettle();
      expect(salon.journal, ['activation p1 false']);
      expect(
        find.text('Désactivée : plus proposée aux clients'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('n\'est plus proposée aux clients'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Réactiver Coupe femme'));
      await tester.pumpAndSettle();
      expect(salon.journal.last, 'activation p1 true');
    });

    testWidgets(
      'refus de la base : message clair, on reste sur le formulaire',
      (tester) async {
        await ouvrir(tester, EcranPrestations(salon: salon));
        await tester.tap(find.text('Ajouter une prestation'));
        await tester.pumpAndSettle();
        salon.prochaineErreur = ErreurSalon(messageErreurBase('42501'));
        await saisir(tester, 'Nom', 'Promo');
        await saisir(tester, 'Prix', '1');
        await saisir(tester, 'Durée', '30');
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(
          find.text('Action réservée au gérant du salon.'),
          findsOneWidget,
        );
        expect(find.text('Nouvelle prestation'), findsOneWidget);
      },
    );
  });

  group('Fiche coiffeur (BF-G1, BF-G3)', () {
    const amira = Coiffeur(id: 'c1', nom: 'Amira');

    testWidgets(
      'horaires : les 7 jours, ajout d\'une plage, chevauchement refusé',
      (tester) async {
        await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
        expect(find.text('Ne travaille pas'), findsNWidgets(7));

        await tester.tap(find.text('Ajouter une plage'));
        await tester.pumpAndSettle();
        expect(find.text('Nouvelle plage'), findsOneWidget);
        await tester.tap(find.text('Ajouter'));
        await tester.pumpAndSettle();
        expect(salon.journal, ['plage c1 1 09:00-18:00']);
        expect(find.text('09:00 – 18:00'), findsOneWidget);
        expect(find.text('Ne travaille pas'), findsNWidgets(6));

        await tester.tap(find.text('Ajouter une plage'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ajouter'));
        await tester.pumpAndSettle();
        expect(
          find.text('Cette plage chevauche une autre plage de ce coiffeur.'),
          findsOneWidget,
        );
        expect(find.text('09:00 – 18:00'), findsOneWidget);

        await tester.tap(
          find.byTooltip('Supprimer la plage du Lundi 09:00 – 18:00'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Ne travaille pas'), findsNWidgets(7));
      },
    );

    testWidgets(
      'absence sur des rendez-vous confirmés : avertissement, sans blocage',
      (tester) async {
        salon.rendezVous = 2;
        await ouvrir(
          tester,
          FormulaireAbsence(
            salon: salon,
            coiffeur: amira,
            maintenant: DateTime(2030, 1, 6),
          ),
        );
        // Par défaut : demain 9h-19h.
        expect(find.text('Lundi 7 janvier'), findsNWidgets(2));
        expect(find.text('09:00'), findsOneWidget);
        expect(find.text('19:00'), findsOneWidget);

        await saisir(tester, 'Motif', 'Formation');
        await tester.tap(find.text('Enregistrer l\'absence'));
        await tester.pumpAndSettle();
        expect(find.textContaining('2 rendez-vous confirmés'), findsOneWidget);
        expect(
          find.textContaining('les clients ne sont pas prévenus'),
          findsOneWidget,
        );

        await tester.tap(find.text('Revenir'));
        await tester.pumpAndSettle();
        expect(salon.journal, isEmpty);

        await tester.tap(find.text('Enregistrer l\'absence'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enregistrer quand même'));
        await tester.pumpAndSettle();
        expect(salon.journal, [
          'absence c1 ${DateTime(2030, 1, 7, 9)} ${DateTime(2030, 1, 7, 19)} Formation',
        ]);
      },
    );

    testWidgets(
      'absence sans rendez-vous : enregistrée directement, puis listée',
      (tester) async {
        salon.absencesEnregistrees['c1'] = [
          Absence(
            id: 'a1',
            debut: DateTime(2030, 1, 14, 9),
            fin: DateTime(2030, 1, 14, 12),
            motif: 'Congé',
          ),
        ];
        await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
        expect(find.text('Du Lundi 14 janvier, 09:00'), findsOneWidget);
        expect(find.text('au Lundi 14 janvier, 12:00'), findsOneWidget);
        expect(find.text('Congé'), findsOneWidget);

        await tester.tap(
          find.byTooltip('Supprimer l\'absence du Lundi 14 janvier, 09:00'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aucune absence prévue.'), findsOneWidget);
      },
    );

    testWidgets(
      'compétences : cocher et décocher ; échec remis à l\'état précédent',
      (tester) async {
        await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
        CheckboxListTile case_(String nom) => tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, nom),
        );
        expect(case_('Coupe femme').value, isTrue);
        expect(case_('Barbe').value, isFalse);

        await appuyer(tester, find.widgetWithText(CheckboxListTile, 'Barbe'));
        expect(case_('Barbe').value, isTrue);
        expect(salon.journal, ['ajouter competence c1 p2']);

        salon.prochaineErreur = ErreurSalon(messageErreurBase(null));
        await appuyer(
          tester,
          find.widgetWithText(CheckboxListTile, 'Coupe femme'),
        );
        expect(case_('Coupe femme').value, isTrue);
        expect(
          find.textContaining('L\'enregistrement a échoué'),
          findsOneWidget,
        );
      },
    );
  });
}
