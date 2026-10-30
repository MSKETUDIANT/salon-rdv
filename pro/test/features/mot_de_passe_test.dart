import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/roles.dart';
import 'package:salon_pro/data/session.dart';
import 'package:salon_pro/features/espaces/ecran_mot_de_passe.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';

// Changer de mot de passe (#107) : contrôles avant l'envoi, refus de Supabase
// Auth sur le bon champ, retour au profil avec un message.

// Appels reçus (« actuel → nouveau ») et réponse à renvoyer.
final appels = <String>[];
ErreurMotDePasse? reponse;

Future<ErreurMotDePasse?> changer(String actuel, String nouveau) async {
  appels.add('$actuel → $nouveau');
  return reponse;
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

Future<void> saisir(WidgetTester tester, String actuel, String nouveau) async {
  await tester.enterText(find.byType(TextField).at(0), actuel);
  await tester.enterText(find.byType(TextField).at(1), nouveau);
  await appuyer(tester, find.text('Enregistrer'));
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() {
    appels.clear();
    reponse = null;
  });

  testWidgets('champs vides, trop court, identique : rien n\'est envoyé', (
    tester,
  ) async {
    await monter(tester, const EcranMotDePasse(changer: changer));
    expect(find.text('8 caractères au moins.'), findsOneWidget);

    await appuyer(tester, find.text('Enregistrer'));
    expect(find.text('Indiquez votre mot de passe actuel.'), findsOneWidget);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);

    await saisir(tester, 'motdepasse', 'court');
    expect(find.text('Indiquez votre mot de passe actuel.'), findsNothing);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);

    await saisir(tester, 'motdepasse', 'motdepasse');
    expect(
      find.text("Choisissez un mot de passe différent de l'actuel."),
      findsOneWidget,
    );
    expect(appels, isEmpty);
  });

  testWidgets('mot de passe actuel refusé : message sous ce champ', (
    tester,
  ) async {
    reponse = ErreurMotDePasse.actuelIncorrect;
    await monter(tester, const EcranMotDePasse(changer: changer));
    await saisir(tester, 'faux', 'nouveau-mdp');
    expect(appels, ['faux → nouveau-mdp']);
    expect(find.text('Mot de passe actuel incorrect.'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });

  testWidgets('trop faible pour Supabase : message sous le nouveau', (
    tester,
  ) async {
    reponse = ErreurMotDePasse.tropFaible;
    await monter(tester, const EcranMotDePasse(changer: changer));
    await saisir(tester, 'motdepasse', 'azertyui');
    expect(
      find.text('Mot de passe trop faible : 8 caractères au moins.'),
      findsOneWidget,
    );
  });

  testWidgets('réseau : message général au-dessus du bouton', (tester) async {
    reponse = ErreurMotDePasse.reseau;
    await monter(tester, const EcranMotDePasse(changer: changer));
    await saisir(tester, 'motdepasse', 'nouveau-mdp');
    expect(
      find.text('Connexion impossible. Vérifiez le réseau, puis réessayez.'),
      findsOneWidget,
    );
  });

  testWidgets('profil : ligne « Mot de passe », puis message au retour', (
    tester,
  ) async {
    await monter(
      tester,
      OngletProfil(
        compte: 'amira@salon.test',
        espace: Espace.coiffeur,
        planning: FauxPlanning(),
        surDeconnexion: () {},
        changerMotDePasse: changer,
      ),
    );
    // Plus aucune entrée « Bientôt » depuis #106 et #107.
    expect(find.text('Bientôt'), findsNothing);
    await appuyer(tester, find.bySemanticsLabel('Mot de passe'));
    expect(find.text('Mot de passe actuel'), findsOneWidget);

    await saisir(tester, 'motdepasse', 'nouveau-mdp');
    expect(appels, ['motdepasse → nouveau-mdp']);
    expect(find.text('Mot de passe actuel'), findsNothing);
    expect(find.text('Mot de passe modifié.'), findsOneWidget);
  });

  test('codes de Supabase Auth', () {
    expect(erreurMotDePasse('weak_password'), ErreurMotDePasse.tropFaible);
    expect(erreurMotDePasse('same_password'), ErreurMotDePasse.identique);
    expect(
      erreurMotDePasse('over_request_rate_limit'),
      ErreurMotDePasse.tropDeTentatives,
    );
    expect(erreurMotDePasse('inconnu'), ErreurMotDePasse.autre);
  });
}
