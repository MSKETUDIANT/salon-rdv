import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/session.dart';
import 'package:salon_pro/features/connexion/ecran_premiere_connexion.dart';
import 'package:salon_pro/ui/charte.dart';

// Première connexion d'un coiffeur invité (#145) : message neutre, contrôles
// avant l'envoi, refus de Supabase Auth sur le bon champ. Parcours complet
// jusqu'à l'espace (ou « Accès réservé à l'équipe ») : porte_test.dart.

class FausseAuthPremiere implements ServiceAuth {
  final appels = <String>[];
  ErreurOubli? refusEnvoi;
  ErreurOubli? refusCode;

  @override
  String? get compte => null;
  @override
  Stream<String?> get changements => const Stream.empty();
  @override
  Future<String?> seConnecter(String email, String motDePasse) async => null;
  @override
  Future<void> seDeconnecter() async {}
  @override
  Future<ErreurMotDePasse?> changerMotDePasse(
    String actuel,
    String nouveau,
  ) async => null;
  @override
  Future<ErreurOubli?> envoyerCodeOubli(String email) async => null;
  @override
  Future<ErreurOubli?> reinitialiserMotDePasse(
    String email,
    String code,
    String nouveau,
  ) async => null;

  @override
  Future<ErreurOubli?> envoyerCodePremiereConnexion(String email) async {
    appels.add('code $email');
    return refusEnvoi;
  }

  @override
  Future<ErreurOubli?> creerAcces(
    String email,
    String code,
    String motDePasse,
  ) async {
    appels.add('accès $email $code $motDePasse');
    return refusCode;
  }
}

late FausseAuthPremiere auth;

Future<void> monter(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: EcranPremiereConnexion(auth: auth),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> appuyer(WidgetTester tester, String texte) async {
  final cible = find.text(texte);
  await tester.ensureVisible(cible);
  await tester.pumpAndSettle();
  await tester.tap(cible);
  await tester.pumpAndSettle();
}

final champs = find.byType(TextField);

Future<void> demanderCode(WidgetTester tester) async {
  await tester.enterText(champs, 'nour@salon.test');
  await appuyer(tester, 'Recevoir un code');
}

void main() {
  setUp(() => auth = FausseAuthPremiere());

  testWidgets("adresse non valable : message, rien n'est envoyé", (
    tester,
  ) async {
    await monter(tester);
    await tester.enterText(champs, 'pas-une-adresse');
    await appuyer(tester, 'Recevoir un code');
    expect(find.text('Indiquez une adresse e-mail valide.'), findsOneWidget);
    expect(auth.appels, isEmpty);
  });

  testWidgets('code demandé : message neutre, trois champs', (tester) async {
    await monter(tester);
    expect(
      find.textContaining("l'adresse e-mail de l'invitation"),
      findsOneWidget,
    );
    await demanderCode(tester);
    expect(auth.appels, ['code nour@salon.test']);
    expect(
      find.text(
        "Un e-mail vient d'être envoyé à cette adresse avec un code à 6 chiffres.",
      ),
      findsOneWidget,
    );
    expect(champs, findsNWidgets(3));
    expect(find.text('Créer mon accès'), findsOneWidget);
  });

  testWidgets("trop de demandes : message, on reste à l'étape 1", (
    tester,
  ) async {
    auth.refusEnvoi = ErreurOubli.tropDeDemandes;
    await monter(tester);
    await demanderCode(tester);
    expect(find.text(ErreurOubli.tropDeDemandes.message), findsOneWidget);
    expect(champs, findsOneWidget);
  });

  testWidgets("code, longueur, confirmation : vérifiés avant l'envoi", (
    tester,
  ) async {
    await monter(tester);
    await demanderCode(tester);
    await tester.enterText(champs.at(0), '12');
    await tester.enterText(champs.at(1), 'court');
    await tester.enterText(champs.at(2), 'autre');
    await appuyer(tester, 'Créer mon accès');
    expect(find.text('Le code a 6 chiffres.'), findsOneWidget);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);
    expect(
      find.text('Les deux mots de passe ne sont pas identiques.'),
      findsOneWidget,
    );
    expect(auth.appels, ['code nour@salon.test']);
  });

  testWidgets('code refusé : message sous le code', (tester) async {
    auth.refusCode = ErreurOubli.codeInvalide;
    await monter(tester);
    await demanderCode(tester);
    await tester.enterText(champs.at(0), '000000');
    await tester.enterText(champs.at(1), 'mon-mdp-nour');
    await tester.enterText(champs.at(2), 'mon-mdp-nour');
    await appuyer(tester, 'Créer mon accès');
    expect(auth.appels.last, 'accès nour@salon.test 000000 mon-mdp-nour');
    expect(find.text(ErreurOubli.codeInvalide.message), findsOneWidget);
    expect(find.byType(EcranPremiereConnexion), findsOneWidget);
  });

  testWidgets('renvoyer le code : nouvel envoi, message', (tester) async {
    await monter(tester);
    await demanderCode(tester);
    await appuyer(tester, 'Renvoyer le code');
    expect(auth.appels, ['code nour@salon.test', 'code nour@salon.test']);
    expect(find.text('Nouveau code envoyé.'), findsOneWidget);
  });
}
