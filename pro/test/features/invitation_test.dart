import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/features/gerant/ecran_equipe.dart';
import 'package:salon_pro/features/gerant/ecran_inviter_coiffeur.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_salon.dart';

// Inviter un coiffeur (#145, #148) : bouton « Ajouter un coiffeur » de
// l'écran Équipe, formulaire, e-mail envoyé, invitations en attente avec le
// menu « Renvoyer » / « Annuler ». Droits, format et confirmation de
// l'invité : invitation_coiffeur.test.sql et invitation_par_email.test.sql ;
// envoi de l'e-mail : supabase/functions/inviter-coiffeur ; code reçu
// jusqu'à l'espace : porte_test.dart.

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

  Future<void> menu(WidgetTester tester, String nom, String action) async {
    await appuyer(tester, find.byTooltip("Actions sur l'invitation de $nom"));
    await appuyer(tester, find.text(action));
  }

  testWidgets('nouvelle adresse : e-mail envoyé, en attente, puis annulée', (
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
    expect(find.text('Invitation envoyée à Nour Ben.'), findsOneWidget);
    expect(find.text('Invitations en attente'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Nour Ben, invitation en attente, nour@salon.test'),
      findsOneWidget,
    );

    await menu(tester, 'Nour Ben', "Annuler l'invitation");
    expect(salon.actionsInvitation.last, 'annulé inv-nour@salon.test');
    expect(find.text('Invitations en attente'), findsNothing);
    expect(find.text("Invitation de Nour Ben annulée."), findsOneWidget);
    semantique.dispose();
  });

  testWidgets(
    "« Renvoyer l'invitation » : nouvel e-mail, toujours en attente",
    (tester) async {
      salon.invitationsEnAttente.add(
        const Invitation(id: 'inv-1', nom: 'Nour', email: 'nour@salon.test'),
      );
      await monter(tester, EcranEquipe(salon: salon));
      await menu(tester, 'Nour', "Renvoyer l'invitation");
      expect(salon.actionsInvitation, ['renvoyé nour@salon.test']);
      expect(find.text('Invitation envoyée à Nour.'), findsOneWidget);
      expect(find.text('Invitations en attente'), findsOneWidget);
    },
  );

  testWidgets("e-mail refusé (limite d'envoi) : invitation gardée, le dire", (
    tester,
  ) async {
    salon.emailRefuse = true;
    await monter(tester, EcranEquipe(salon: salon));
    await appuyer(tester, find.text('Ajouter un coiffeur'));
    await remplir(tester, 'Nour', 'nour@salon.test');
    expect(
      find.text(
        "Invitation enregistrée pour Nour, mais l'e-mail n'est pas parti. "
        'Renvoyez-le dans quelques minutes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Invitations en attente'), findsOneWidget);
  });

  testWidgets("formulaire : dit qu'un e-mail part, avec le lien de l'app", (
    tester,
  ) async {
    await monter(tester, EcranInviterCoiffeur(salon: salon));
    expect(
      find.text(
        "Un e-mail d'invitation est envoyé à cette adresse, avec le lien de "
        "l'app et la marche à suivre.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Première connexion'), findsNothing);
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
