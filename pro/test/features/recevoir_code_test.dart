import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/session.dart';
import 'package:salon_pro/features/connexion/ecran_recevoir_code.dart';
import 'package:salon_pro/ui/charte.dart';

// « Pas encore de mot de passe, ou oublié ? » (#148, après #39 et #145) :
// message neutre, contrôles avant l'envoi, refus de Supabase Auth sur le bon
// champ. Parcours complets jusqu'à l'espace : porte_test.dart.

class FausseAuthOubli implements ServiceAuth {
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
  Future<ErreurOubli?> envoyerCode(String email) async {
    appels.add('code $email');
    return refusEnvoi;
  }

  @override
  Future<ErreurOubli?> connecterAvecCode(
    String email,
    String code,
    String motDePasse,
  ) async {
    appels.add('connexion $email $code $motDePasse');
    return refusCode;
  }
}

late FausseAuthOubli auth;

Future<void> monter(WidgetTester tester, {String email = ''}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: themeCharte(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: EcranRecevoirCode(auth: auth, email: email),
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

Future<void> saisirEtValider(
  WidgetTester tester,
  String code,
  String nouveau,
  String confirmation,
) async {
  await tester.enterText(champs.at(0), code);
  await tester.enterText(champs.at(1), nouveau);
  await tester.enterText(champs.at(2), confirmation);
  await appuyer(tester, 'Se connecter');
}

void main() {
  setUp(() => auth = FausseAuthOubli());

  testWidgets("adresse non valable : message, rien n'est envoyé", (
    tester,
  ) async {
    await monter(tester);
    await tester.enterText(champs, 'amira');
    await appuyer(tester, 'Recevoir un code');
    expect(find.text('Indiquez une adresse e-mail valide.'), findsOneWidget);
    expect(auth.appels, isEmpty);
  });

  testWidgets('écran : titre et texte valables pour une invitation', (
    tester,
  ) async {
    await monter(tester);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.textContaining('celle de votre invitation'), findsOneWidget);
    expect(
      find.textContaining('pour choisir votre mot de passe'),
      findsOneWidget,
    );
  });

  testWidgets('code demandé : message neutre, trois champs', (tester) async {
    await monter(tester, email: 'inconnu@salon.test');
    await appuyer(tester, 'Recevoir un code');
    expect(auth.appels, ['code inconnu@salon.test']);
    expect(
      find.text(
        "Si un compte existe pour cette adresse, un e-mail vient d'être "
        'envoyé avec un code à 6 chiffres.',
      ),
      findsOneWidget,
    );
    expect(champs, findsNWidgets(3));
    expect(find.text('Renvoyer le code'), findsOneWidget);
  });

  testWidgets("trop de demandes : message, on reste à l'étape 1", (
    tester,
  ) async {
    auth.refusEnvoi = ErreurOubli.tropDeDemandes;
    await monter(tester, email: 'amira@salon.test');
    await appuyer(tester, 'Recevoir un code');
    expect(
      find.text('Trop de demandes. Réessayez dans une minute.'),
      findsOneWidget,
    );
    expect(champs, findsOneWidget);
  });

  testWidgets("code, longueur, confirmation : vérifiés avant l'envoi", (
    tester,
  ) async {
    await monter(tester, email: 'amira@salon.test');
    await appuyer(tester, 'Recevoir un code');
    await saisirEtValider(tester, '12a', 'court', 'autre');
    expect(find.text('Le code a 6 chiffres.'), findsOneWidget);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);
    expect(
      find.text('Les deux mots de passe ne sont pas identiques.'),
      findsOneWidget,
    );
    expect(auth.appels, ['code amira@salon.test']);
  });

  testWidgets('code refusé : message sous le code', (tester) async {
    auth.refusCode = ErreurOubli.codeInvalide;
    await monter(tester, email: 'amira@salon.test');
    await appuyer(tester, 'Recevoir un code');
    await saisirEtValider(tester, '000000', 'nouveau-mdp', 'nouveau-mdp');
    expect(auth.appels.last, 'connexion amira@salon.test 000000 nouveau-mdp');
    expect(
      find.text(
        'Code incorrect ou expiré. Vérifiez-le, ou demandez un nouveau code.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renvoyer le code : nouvel envoi, message', (tester) async {
    await monter(tester, email: 'amira@salon.test');
    await appuyer(tester, 'Recevoir un code');
    await appuyer(tester, 'Renvoyer le code');
    expect(auth.appels, ['code amira@salon.test', 'code amira@salon.test']);
    expect(find.text('Nouveau code envoyé.'), findsOneWidget);
  });

  test('codes de Supabase Auth', () {
    expect(erreurOubli('otp_expired'), ErreurOubli.codeInvalide);
    expect(erreurOubli('weak_password'), ErreurOubli.tropFaible);
    expect(
      erreurOubli('over_email_send_rate_limit'),
      ErreurOubli.tropDeDemandes,
    );
    expect(erreurOubli('inconnu'), ErreurOubli.autre);
  });
}
