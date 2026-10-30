import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salon_pro/data/roles.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/data/session.dart';
import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salon_pro/features/connexion/ecran_connexion.dart';
import 'package:salon_pro/features/espaces/ecran_espace.dart';
import 'package:salon_pro/features/espaces/ecran_mot_de_passe.dart';
import 'package:salon_pro/features/espaces/onglets.dart';
import 'package:salon_pro/features/gerant/ecran_coiffeur.dart';
import 'package:salon_pro/features/gerant/ecran_equipe.dart';
import 'package:salon_pro/features/gerant/ecran_prestations.dart';
import 'package:salon_pro/features/historique/ecran_historique.dart';
import 'package:salon_pro/features/planning/ecran_mon_planning.dart';
import 'package:salon_pro/features/planning/ecran_planning_equipe.dart';
import 'package:salon_pro/features/planning/formulaire_encaissement.dart';
import 'package:salon_pro/ui/charte.dart';

import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Contrôles d'accessibilité de Flutter sur chaque écran de l'app pro, à
// 360 × 640 (#41, BNF-10, BNF-11) : zones tactiles d'au moins 48 × 48 px
// (Android, plus strict que les 44 px de la charte), chaque élément
// interactif libellé pour TalkBack, contraste du texte (WCAG 2.2 AA).

Future<void> verifier(WidgetTester tester, Widget ecran) async {
  final semantique = tester.ensureSemantics();
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
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
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  semantique.dispose();
}

class _AuthMuette implements ServiceAuth {
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
}

void main() {
  // Préférences de l'app simulées ; l'indice des gestes déjà vu (#64).
  setUp(() {
    SharedPreferences.setMockInitialValues({cleIndiceGestes: true});
    reinitialiserIndice();
  });
  setUpAll(() => initializeDateFormatting('fr'));
  const amira = Coiffeur(id: 'c1', nom: 'Amira');

  final ecrans = <String, Widget Function()>{
    'connexion': () => EcranConnexion(auth: _AuthMuette()),
    'accueil du gérant qui est aussi coiffeur': () => EcranEspace(
      espace: Espace.gerant,
      salon: FauxSalon(),
      planning: FauxPlanning(),
      compte: 'patron@salon.test',
      autreEspace: Espace.coiffeur,
      surBascule: (_) {},
      surDeconnexion: () {},
      changerMotDePasse: (_, _) async => null,
    ),
    'accueil du coiffeur': () => EcranEspace(
      espace: Espace.coiffeur,
      salon: FauxSalon(),
      planning: FauxPlanning(),
      compte: 'amira@salon.test',
      surBascule: (_) {},
      surDeconnexion: () {},
      changerMotDePasse: (_, _) async => null,
    ),
    "aujourd'hui du gérant": () =>
        EcranAujourdhui(planning: FauxPlanning(), gerant: true),
    'onglet Salon du gérant': () =>
        OngletSalonGerant(salon: FauxSalon(), planning: FauxPlanning()),
    'onglet Salon du coiffeur': () =>
        OngletSalonCoiffeur(planning: FauxPlanning()),
    'onglet Profil': () => OngletProfil(
      compte: 'patron@salon.test',
      espace: Espace.gerant,
      planning: FauxPlanning(),
      autreEspace: Espace.coiffeur,
      surBascule: (_) {},
      surDeconnexion: () {},
      changerMotDePasse: (_, _) async => null,
    ),
    'mot de passe': () => EcranMotDePasse(changer: (_, _) async => null),
    'mon planning': () => EcranMonPlanning(planning: FauxPlanning()),
    "planning de l'équipe": () => EcranPlanningEquipe(planning: FauxPlanning()),
    'historique': () => EcranHistorique(planning: FauxPlanning()),
    'encaissement': () => FormulaireEncaissement(
      planning: FauxPlanning(),
      rendezVousId: 'r1',
      resume: 'Lundi 7 janvier, 09:00 · Salma · Coupe',
      prix: 25,
    ),
    'prestations': () => EcranPrestations(salon: FauxSalon()),
    'nouvelle prestation': () => FormulairePrestation(salon: FauxSalon()),
    'équipe': () => EcranEquipe(salon: FauxSalon()),
    'fiche coiffeur': () => EcranCoiffeur(salon: FauxSalon(), coiffeur: amira),
    'nouvelle absence': () =>
        FormulaireAbsence(salon: FauxSalon(), coiffeur: amira),
  };

  testWidgets('les contrôles détectent les défauts', (tester) async {
    final semantique = tester.ensureSemantics();
    Future<void> afficher(Widget enfant) => tester.pumpWidget(
      MaterialApp(
        theme: themeCharte(),
        home: Scaffold(body: Center(child: enfant)),
      ),
    );

    await afficher(
      Semantics(
        label: 'Petit',
        button: true,
        child: GestureDetector(
          onTap: () {},
          child: const SizedBox(width: 30, height: 30),
        ),
      ),
    );
    expect(
      await androidTapTargetGuideline.evaluate(tester),
      isA<Evaluation>().having((e) => e.passed, 'passed', isFalse),
    );

    await afficher(
      GestureDetector(
        onTap: () {},
        child: const SizedBox(width: 48, height: 48),
      ),
    );
    expect(
      await labeledTapTargetGuideline.evaluate(tester),
      isA<Evaluation>().having((e) => e.passed, 'passed', isFalse),
    );

    await afficher(
      const Text('Pâle', style: TextStyle(color: Color(0xFFBBBBBB))),
    );
    expect(
      await textContrastGuideline.evaluate(tester),
      isA<Evaluation>().having((e) => e.passed, 'passed', isFalse),
    );
    semantique.dispose();
  });

  for (final MapEntry(key: nom, value: ecran) in ecrans.entries) {
    testWidgets('$nom : zones tactiles, libellés, contrastes', (tester) async {
      await verifier(tester, ecran());
    });
  }

  // Police agrandie dans les réglages du téléphone (#83) : à 130 % et 200 %,
  // à 360 × 640, aucun débordement (Flutter fait échouer le test sinon).
  // Avec les vraies polices : celle des tests donne 16 px à chaque caractère,
  // bien plus large que Figtree.
  setUpAll(() async {
    for (final (famille, fichier) in [
      (policeTexte, 'assets/fonts/Figtree.ttf'),
      (policeTitre, 'assets/fonts/Newsreader.ttf'),
    ]) {
      final octets = File(fichier).readAsBytesSync();
      await (FontLoader(
        famille,
      )..addFont(Future.value(ByteData.sublistView(octets)))).load();
    }
  });
  for (final echelle in [1.3, 2.0]) {
    for (final MapEntry(key: nom, value: ecran) in ecrans.entries) {
      testWidgets('$nom : police à ${(echelle * 100).round()} %', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: themeCharte(),
            locale: const Locale('fr'),
            supportedLocales: const [Locale('fr')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, enfant) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(echelle)),
              child: enfant!,
            ),
            home: ecran(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
