import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/gerant/ecran_equipe.dart';
import 'package:salon_pro/features/gerant/ecran_inviter_coiffeur.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_salon.dart';

// Inviter un coiffeur (#145, option A) : bouton « Ajouter un coiffeur » de
// l'écran Équipe, formulaire, invitations en attente et « Annuler ». Droits,
// format et inscription de l'invité : invitation_coiffeur.test.sql ;
// première connexion jusqu'à l'espace : porte_test.dart.

late FauxSalon salon;

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

Future<void> remplir(WidgetTester tester, String nom, String email) async {
  await tester.enterText(find.byType(TextField).at(0), nom);
  await tester.enterText(find.byType(TextField).at(1), email);
  await appuyer(tester, find.text('Inviter'));
}

void main() {
  setUp(() => salon = FauxSalon());

  testWidgets('nouvelle adresse : invitation en attente, puis « Annuler »', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    await monter(tester, EcranEquipe(salon: salon));
    expect(find.text('Invitations en attente'), findsNothing);

    await appuyer(tester, find.text('Ajouter un coiffeur'));
    expect(find.byType(EcranInviterCoiffeur), findsOneWidget);
    await remplir(tester, '  Nour   Ben ', ' Nour@Salon.test ');

    expect(salon.actionsInvitation, ['invité nour@salon.test']);
    expect(find.byType(EcranInviterCoiffeur), findsNothing);
    expect(find.text('Invitation enregistrée pour Nour Ben.'), findsOneWidget);
    expect(find.text('Invitations en attente'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Nour Ben, invitation en attente, nour@salon.test'),
      findsOneWidget,
    );

    await appuyer(
      tester,
      find.bySemanticsLabel("Annuler l'invitation de Nour Ben"),
    );
    expect(salon.actionsInvitation.last, 'annulé inv-nour@salon.test');
    expect(find.text('Invitations en attente'), findsNothing);
    expect(find.text("Invitation de Nour Ben annulée."), findsOneWidget);
    semantique.dispose();
  });

  testWidgets(
    "compte existant : rejoint l'équipe tout de suite, sans invitation",
    (tester) async {
      salon.comptesExistants['salma@salon.test'] = 'c-salma';
      await monter(tester, EcranEquipe(salon: salon));
      await appuyer(tester, find.text('Ajouter un coiffeur'));
      await remplir(tester, 'Salma', 'salma@salon.test');

      expect(salon.actionsInvitation, ['ajouté salma@salon.test']);
      expect(
        find.text("Salma fait maintenant partie de l'équipe."),
        findsOneWidget,
      );
      expect(find.text('Invitations en attente'), findsNothing);
      expect(
        find.bySemanticsLabel('Salma, horaires, absences et compétences'),
        findsOneWidget,
      );
    },
  );

  testWidgets('champs vides ou adresse invalide : rien n\'est envoyé', (
    tester,
  ) async {
    await monter(tester, EcranInviterCoiffeur(salon: salon));
    await remplir(tester, '   ', 'pas-une-adresse');
    expect(find.text('Indiquez le nom du coiffeur.'), findsOneWidget);
    expect(find.text('Indiquez une adresse e-mail valide.'), findsOneWidget);
    expect(salon.actionsInvitation, isEmpty);
  });

  testWidgets("déjà dans l'équipe : message de la base, écran gardé", (
    tester,
  ) async {
    salon.comptesExistants['amira@salon.test'] = 'c1';
    await monter(tester, EcranInviterCoiffeur(salon: salon));
    await remplir(tester, 'Amira', 'amira@salon.test');
    expect(find.text("Déjà dans l'équipe."), findsOneWidget);
    expect(find.byType(EcranInviterCoiffeur), findsOneWidget);
  });

  testWidgets('équipe vide : message qui dit comment inviter', (tester) async {
    await monter(tester, EcranEquipe(salon: FauxSalon(coiffeurs: [])));
    expect(
      find.textContaining("Aucun coiffeur pour l'instant."),
      findsOneWidget,
    );
    expect(find.text('Ajouter un coiffeur'), findsOneWidget);
  });

  testWidgets('erreur réseau à l\'invitation : message, écran gardé', (
    tester,
  ) async {
    salon.prochaineErreur = const ErreurSalon('Pas de connexion.');
    await monter(tester, EcranInviterCoiffeur(salon: salon));
    await remplir(tester, 'Nour', 'nour@salon.test');
    expect(find.text('Pas de connexion.'), findsOneWidget);
    expect(find.byType(EcranInviterCoiffeur), findsOneWidget);
  });
}
