import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:salon_pro/features/planning/elements_planning.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../doublures/faux_planning.dart';

// Client arrivé (#102, options 1A et 2a) : état « Arrivé », fiche du
// rendez-vous, carte du prochain rendez-vous de l'accueil. Droits, jour du
// rendez-vous et règle « arrivé, pas absent » : client_arrive.test.sql.
// Dans la doublure, il est lundi 7 janvier 2030, 10:00.

late FauxPlanning planning;

RendezVous rdv(
  String id,
  int jour,
  int h,
  int m, {
  DateTime? arriveLe,
  StatutRendezVous statut = StatutRendezVous.confirmee,
}) {
  final debut = DateTime(2030, 1, jour, h, m);
  return RendezVous(
    id: id,
    coiffeurId: 'c1',
    debut: debut,
    fin: debut.add(const Duration(minutes: 30)),
    statut: statut,
    prestation: 'Coupe',
    dureeMinutes: 30,
    clientNom: 'Salma',
    prix: 20,
    arriveLe: arriveLe,
  );
}

final arriveeA0955 = DateTime(2030, 1, 7, 9, 55);

Future<void> monter(WidgetTester tester, Widget ecran) async {
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

// Message renvoyé par la fiche à sa fermeture.
String? messageFiche;

// Ouvre la fiche de r, à 10:00.
Future<void> ouvrirFiche(WidgetTester tester, RendezVous r) async {
  messageFiche = null;
  await monter(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => messageFiche = await afficherRendezVous(
            context,
            r,
            planning: planning,
            maintenant: planning.maintenant,
            gerant: false,
          ),
          child: const Text('fiche'),
        ),
      ),
    ),
  );
  await appuyer(tester, find.text('fiche'));
}

final boutonArrivee = find.widgetWithText(FilledButton, 'Client arrivé');
final boutonArriveeSecondaire = find.widgetWithText(
  OutlinedButton,
  'Client arrivé',
);

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() {
    planning = FauxPlanning();
    SharedPreferences.setMockInitialValues({});
    reinitialiserIndice();
  });

  test('état : « Arrivé » avant l\'heure, « En cours » ensuite', () {
    final maintenant = DateTime(2030, 1, 7, 10);
    expect(rdv('a', 7, 11, 0).etat(maintenant), EtatRendezVous.aVenir);
    expect(
      rdv('a', 7, 11, 0, arriveLe: arriveeA0955).etat(maintenant),
      EtatRendezVous.arrive,
    );
    expect(
      rdv('a', 7, 9, 50, arriveLe: arriveeA0955).etat(maintenant),
      EtatRendezVous.enCours,
    );
    expect(rdv('a', 7, 11, 0).arriveePossible(maintenant), isTrue);
    expect(rdv('a', 9, 11, 0).arriveePossible(maintenant), isFalse);
    expect(
      rdv(
        'a',
        7,
        9,
        0,
        statut: StatutRendezVous.terminee,
      ).arriveePossible(maintenant),
      isFalse,
    );
  });

  group('fiche', () {
    testWidgets('à venir : « Client arrivé » en bouton principal', (
      tester,
    ) async {
      await ouvrirFiche(tester, rdv('v', 7, 11, 0));
      expect(find.text('Statut'), findsOneWidget);
      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('Arrivée'), findsNothing);
      await appuyer(tester, boutonArrivee);
      expect(planning.actions, ['v arrivé']);
      expect(messageFiche, 'Arrivée de Salma notée.');
    });

    testWidgets('arrivé : heure d\'arrivée, « Annuler l\'arrivée »', (
      tester,
    ) async {
      await ouvrirFiche(tester, rdv('v', 7, 11, 0, arriveLe: arriveeA0955));
      expect(find.text('Arrivé'), findsOneWidget);
      expect(find.text('Arrivée'), findsOneWidget);
      expect(find.text('09:55'), findsOneWidget);
      expect(find.text('Client arrivé'), findsNothing);
      await appuyer(tester, find.text("Annuler l'arrivée"));
      expect(planning.actions, ['v arrivée annulée']);
      expect(messageFiche, 'Arrivée annulée.');
    });

    testWidgets(
      'commencé, pas arrivé : Terminé, Client arrivé, Client absent',
      (tester) async {
        await ouvrirFiche(tester, rdv('c', 7, 9, 45));
        expect(find.widgetWithText(FilledButton, 'Terminé'), findsOneWidget);
        expect(boutonArriveeSecondaire, findsOneWidget);
        expect(find.text('Client absent'), findsOneWidget);
      },
    );

    testWidgets('commencé et arrivé : pas de « Client absent »', (
      tester,
    ) async {
      await ouvrirFiche(tester, rdv('c', 7, 9, 45, arriveLe: arriveeA0955));
      expect(find.widgetWithText(FilledButton, 'Terminé'), findsOneWidget);
      expect(find.text('Client absent'), findsNothing);
      expect(find.text("Annuler l'arrivée"), findsOneWidget);
    });

    testWidgets('un autre jour : pas de « Client arrivé »', (tester) async {
      await ouvrirFiche(tester, rdv('m', 9, 11, 0));
      expect(find.text('Client arrivé'), findsNothing);
    });

    testWidgets('refus de la base : message dans la fiche', (tester) async {
      planning.erreurAction = const ErreurSalon(
        'Arrivée possible seulement le jour du rendez-vous.',
      );
      await ouvrirFiche(tester, rdv('v', 7, 11, 0));
      await appuyer(tester, boutonArrivee);
      expect(
        find.text('Arrivée possible seulement le jour du rendez-vous.'),
        findsOneWidget,
      );
      expect(messageFiche, isNull);
    });
  });

  group('accueil, prochain rendez-vous', () {
    testWidgets('« Client arrivé » en un geste, puis l\'heure d\'arrivée', (
      tester,
    ) async {
      planning.rendezVous = [rdv('v', 7, 11, 0)];
      await monter(tester, EcranAujourdhui(planning: planning, gerant: false));
      expect(find.text('Prochain rendez-vous'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Ouvrir la fiche'),
        findsOneWidget,
      );
      await appuyer(tester, boutonArrivee);
      expect(planning.actions, ['v arrivé']);
      expect(find.text('Arrivée de Salma notée.'), findsOneWidget);
      // Relu : la carte reste celle du prochain rendez-vous, arrivé.
      expect(find.text('Arrivé à 10:00'), findsOneWidget);
      expect(find.text('Client arrivé'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Ouvrir la fiche'),
        findsOneWidget,
      );
      // Arrivé : compté dans les restants.
      expect(find.bySemanticsLabel('1 restant'), findsOneWidget);
    });

    testWidgets('refus de la base : message, la carte reste', (tester) async {
      planning.rendezVous = [rdv('v', 7, 11, 0)];
      planning.erreurAction = const ErreurSalon(
        'Ce rendez-vous est déjà clôturé.',
      );
      await monter(tester, EcranAujourdhui(planning: planning, gerant: false));
      await appuyer(tester, boutonArrivee);
      expect(find.text('Ce rendez-vous est déjà clôturé.'), findsOneWidget);
      expect(boutonArrivee, findsOneWidget);
    });
  });
}
