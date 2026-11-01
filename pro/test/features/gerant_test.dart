import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/gerant/ecran_coiffeur.dart';
import 'package:salon_pro/features/gerant/ecran_semaine.dart';
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
        expect(find.text('Désactivée'), findsOneWidget);
        // Interrupteur « proposée aux clients » (#92) : éteint pour la
        // prestation désactivée seulement.
        final interrupteurs = tester.widgetList<Switch>(find.byType(Switch));
        expect(interrupteurs.where((i) => !i.value), hasLength(1));
        // Plus de liens soulignés sur chaque ligne.
        expect(find.text('Modifier'), findsNothing);
        expect(find.byType(Card), findsNothing);
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
        expect(find.text('Prestation ajoutée.'), findsOneWidget);
      },
    );

    testWidgets(
      'formulaire : exemples sous les champs, claviers, Entrée de champ en champ puis enregistre (charte §11)',
      (tester) async {
        await ouvrir(tester, EcranPrestations(salon: salon));
        await tester.tap(find.text('Ajouter une prestation'));
        await tester.pumpAndSettle();
        expect(find.text('Exemple : 35 ou 10,500'), findsOneWidget);
        expect(find.text('Exemple : 45'), findsOneWidget);

        TextField champ(int i) =>
            tester.widget<TextField>(find.byType(TextField).at(i));
        expect(champ(0).textCapitalization, TextCapitalization.sentences);
        expect(
          champ(1).keyboardType,
          const TextInputType.numberWithOptions(decimal: true),
        );
        expect(champ(2).keyboardType, TextInputType.number);
        expect(champ(0).textInputAction, TextInputAction.next);
        expect(champ(1).textInputAction, TextInputAction.next);
        expect(champ(2).textInputAction, TextInputAction.done);

        await tester.tap(find.byType(TextField).at(0));
        await tester.enterText(find.byType(TextField).at(0), 'Soin');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(champ(1).focusNode!.hasFocus, isTrue);
        await tester.enterText(find.byType(TextField).at(1), '20');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(champ(2).focusNode!.hasFocus, isTrue);
        await tester.enterText(find.byType(TextField).at(2), '40');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(salon.journal, ['creer Soin 20.0 40']);
        expect(find.text('Prestation ajoutée.'), findsOneWidget);
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
      await tester.tap(
        find.bySemanticsLabel('Coupe femme proposée aux clients'),
      );
      await tester.pumpAndSettle();
      expect(salon.journal, ['activation p1 false']);
      expect(find.text('Désactivée'), findsNWidgets(2));
      expect(
        find.textContaining('n\'est plus proposée aux clients'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsLabel('Coupe femme proposée aux clients'),
      );
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

    testWidgets('sans cadre : horaires, absences et compétences en lignes', (
      tester,
    ) async {
      await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
      // Logique du lot 2 (#96) : plus aucune carte encadrée.
      expect(find.byType(Card), findsNothing);
      expect(find.text('Horaires'), findsOneWidget);
      expect(find.text('Absences'), findsOneWidget);
      expect(find.text('Compétences'), findsOneWidget);
    });

    // Horaires de la semaine (#151, option B).
    Future<void> toucher(WidgetTester tester, Finder cible) async {
      await tester.ensureVisible(cible);
      await tester.pumpAndSettle();
      await tester.tap(cible);
      await tester.pumpAndSettle();
    }

    const neufH = TimeOfDay(hour: 9, minute: 0);
    const dixHuitH = TimeOfDay(hour: 18, minute: 0);

    // Interrupteur d'un jour, sur l'écran de la semaine.
    Finder interrupteur(String jour) => find.descendant(
      of: find.ancestor(of: find.text(jour), matching: find.byType(Row)).first,
      matching: find.byType(Switch),
    );

    Future<void> ouvrirSemaine(WidgetTester tester, List<Plage> plages) =>
        ouvrir(
          tester,
          EcranSemaine(salon: salon, coiffeur: amira, plages: plages),
        );

    testWidgets(
      "horaires : la fiche résume la semaine, un jour touché ouvre l'écran "
      'de la semaine',
      (tester) async {
        salon.plagesEnregistrees['c1'] = [
          const Plage(id: 'h1', jour: 1, debut: neufH, fin: dixHuitH),
        ];
        await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
        expect(find.text('09:00 – 18:00'), findsOneWidget);
        expect(find.text('Ne travaille pas'), findsNWidgets(6));
        expect(find.byTooltip(RegExp('Supprimer')), findsNothing);

        await toucher(tester, find.text('Mardi'));
        expect(find.byType(EcranSemaine), findsOneWidget);
        // Bouton toujours visible, sans défiler.
        expect(find.text('Enregistrer').hitTestable(), findsOneWidget);
      },
    );

    testWidgets(
      "horaires : un jour allumé reprend les heures du jour travaillé le "
      'plus proche ; copie vers du lundi au vendredi ; une seule '
      'sauvegarde',
      (tester) async {
        await ouvrirSemaine(tester, const [
          Plage(id: 'h1', jour: 1, debut: neufH, fin: dixHuitH),
        ]);
        expect(find.text('Ne travaille pas'), findsNWidgets(6));

        // Mardi allumé : 09:00 – 18:00, comme lundi.
        await toucher(tester, interrupteur('Mardi'));
        expect(find.text('09:00'), findsNWidgets(2));

        // Lundi copié vers du lundi au vendredi.
        await toucher(tester, find.byTooltip('Autres actions du Lundi'));
        await toucher(tester, find.text("Copier vers d'autres jours…"));
        expect(find.text('Copier les horaires du lundi vers…'), findsOneWidget);
        await toucher(tester, find.text('Du lundi au vendredi'));
        await toucher(tester, find.text('Copier vers 4 jours'));
        expect(find.text('Ne travaille pas'), findsNWidgets(2));
        expect(salon.journal, isEmpty);

        await toucher(tester, find.text('Enregistrer'));
        expect(salon.journal, [
          'semaine c1 1 09:00-18:00, 2 09:00-18:00, 3 09:00-18:00, '
              '4 09:00-18:00, 5 09:00-18:00',
        ]);
        expect(find.byType(EcranSemaine), findsNothing);
      },
    );

    testWidgets(
      'horaires : ajouter une pause coupe la journée à midi ; × la retire ; '
      'éteindre un jour',
      (tester) async {
        await ouvrirSemaine(tester, const [
          Plage(id: 'h1', jour: 1, debut: neufH, fin: dixHuitH),
          Plage(id: 'h2', jour: 2, debut: neufH, fin: dixHuitH),
        ]);
        await toucher(tester, find.byTooltip('Autres actions du Lundi'));
        await toucher(tester, find.text('Ajouter une pause'));
        expect(find.text('12:00'), findsOneWidget);
        expect(find.text('13:00'), findsOneWidget);

        await toucher(tester, interrupteur('Mardi'));
        await toucher(tester, find.text('Enregistrer'));
        expect(salon.journal, ['semaine c1 1 09:00-12:00, 1 13:00-18:00']);
      },
    );

    testWidgets("horaires : × retire une plage d'un jour qui en a deux", (
      tester,
    ) async {
      await ouvrirSemaine(tester, const [
        Plage(
          id: 'h1',
          jour: 1,
          debut: neufH,
          fin: TimeOfDay(hour: 12, minute: 0),
        ),
        Plage(
          id: 'h2',
          jour: 1,
          debut: TimeOfDay(hour: 14, minute: 0),
          fin: dixHuitH,
        ),
      ]);
      await toucher(
        tester,
        find.byTooltip('Retirer la plage 14:00 – 18:00 du Lundi'),
      );
      expect(find.text('14:00'), findsNothing);
      expect(find.byTooltip(RegExp('Retirer')), findsNothing);
    });

    testWidgets(
      "horaires : quitter avec des changements demande d'abord ; rien "
      "n'est enregistré",
      (tester) async {
        await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
        await toucher(tester, find.text('Modifier les horaires'));
        await toucher(tester, interrupteur('Lundi'));
        await toucher(tester, find.byType(BackButton));
        expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
        await toucher(tester, find.text('Rester'));
        expect(find.byType(EcranSemaine), findsOneWidget);

        await toucher(tester, find.byType(BackButton));
        await toucher(tester, find.text('Quitter'));
        expect(find.byType(EcranSemaine), findsNothing);
        expect(salon.journal, isEmpty);
      },
    );

    testWidgets("horaires : sans changement, retour direct, sans question", (
      tester,
    ) async {
      await ouvrir(tester, EcranCoiffeur(salon: salon, coiffeur: amira));
      await toucher(tester, find.text('Modifier les horaires'));
      await toucher(tester, find.byType(BackButton));
      expect(find.text('Quitter sans enregistrer ?'), findsNothing);
      expect(find.byType(EcranSemaine), findsNothing);
    });

    testWidgets(
      'horaires : refus de la base (chevauchement) affiché au-dessus du '
      'bouton, écran gardé',
      (tester) async {
        salon.prochaineErreur = const ErreurSalon(
          'Deux plages se chevauchent le lundi.',
        );
        await ouvrirSemaine(tester, const []);
        await toucher(tester, interrupteur('Lundi'));
        await toucher(tester, find.text('Enregistrer'));
        expect(
          find.text('Deux plages se chevauchent le lundi.'),
          findsOneWidget,
        );
        expect(find.byType(EcranSemaine), findsOneWidget);
      },
    );

    testWidgets(
      'absence sur des rendez-vous confirmés : avertissement, sans blocage',
      (tester) async {
        salon.rendezVous = 2;
        await ouvrir(tester, FormulaireAbsence(salon: salon, coiffeur: amira));
        // Par défaut : demain 9h-19h.
        expect(find.text('Lundi 7 janvier'), findsNWidgets(2));
        expect(find.text('09:00'), findsOneWidget);
        expect(find.text('19:00'), findsOneWidget);

        expect(find.text('Exemple : congé, formation'), findsOneWidget);
        await saisir(tester, 'Motif', 'Formation');
        // Entrée sur le dernier champ : enregistre (charte §11).
        await tester.testTextInput.receiveAction(TextInputAction.done);
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
        expect(find.text('Du lundi 14 janvier, 09:00'), findsOneWidget);
        expect(find.text('au lundi 14 janvier, 12:00'), findsOneWidget);
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
        expect(find.text('Compétence ajoutée : Barbe.'), findsOneWidget);
        // Le message bref disparaît (4 s) : il ne recouvre plus les cases.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

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
