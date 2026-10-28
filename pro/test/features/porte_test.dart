import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/app.dart';
import 'package:salon_pro/data/roles.dart';
import 'package:salon_pro/data/session.dart';

import 'package:salon_pro/features/aujourdhui/ecran_aujourdhui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../doublures/faux_planning.dart';
import '../doublures/faux_salon.dart';

// Doublures : comptes du seed (supabase/seed.sql) et leurs rôles.
class FausseAuth implements ServiceAuth {
  FausseAuth(this.comptes);

  // e-mail → mot de passe.
  final Map<String, String> comptes;
  final _flux = StreamController<String?>.broadcast();
  final appels = <String>[];

  @override
  String? compte;

  @override
  Stream<String?> get changements => _flux.stream;

  @override
  Future<String?> seConnecter(String email, String motDePasse) async {
    appels.add(email);
    if (comptes[email] != motDePasse) {
      return messageErreurConnexion('invalid_credentials');
    }
    compte = email;
    _flux.add(email);
    return null;
  }

  @override
  Future<void> seDeconnecter() async {
    compte = null;
    _flux.add(null);
  }
}

class FauxRoles implements DepotRoles {
  FauxRoles(this.auth, this.roles);
  final FausseAuth auth;
  final Map<String, List<String>> roles;
  bool enPanne = false;

  @override
  Future<List<String>> rolesDansLeSalon() async {
    if (enPanne) throw Exception('réseau');
    return roles[auth.compte] ?? [];
  }
}

late FausseAuth auth;
late FauxRoles roles;

Future<void> lancer(WidgetTester tester) async {
  auth = FausseAuth({
    'gerant@salon.test': 'motdepasse',
    'amira@salon.test': 'motdepasse',
    'client@salon.test': 'motdepasse',
    'patron@salon.test': 'motdepasse',
  });
  roles = FauxRoles(auth, {
    'gerant@salon.test': ['gerant', 'client'],
    'amira@salon.test': ['coiffeur'],
    'client@salon.test': ['client'],
    'patron@salon.test': ['gerant', 'coiffeur'],
  });
  await tester.pumpWidget(
    AppPro(
      auth: auth,
      roles: roles,
      salon: FauxSalon(),
      planning: FauxPlanning(),
    ),
  );
}

// Petit téléphone : 360 × 640 (Small_Phone, BNF-10).
void petitEcran(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

// Entièrement à l'écran, sans défiler.
void visibleSansDefiler(WidgetTester tester, Finder cible) {
  final ecran = tester.view.physicalSize / 2;
  final zone = tester.getRect(cible);
  // Bords compris (la barre d'onglets finit au bord bas de l'écran).
  expect(
    zone.left >= 0 &&
        zone.top >= 0 &&
        zone.right <= ecran.width &&
        zone.bottom <= ecran.height,
    isTrue,
    reason: "$cible hors de l'écran : $zone",
  );
}

Future<void> ouvrirOnglet(WidgetTester tester, String onglet) async {
  await tester.tap(find.widgetWithText(NavigationDestination, onglet));
  await tester.pumpAndSettle();
}

Future<void> seConnecter(
  WidgetTester tester,
  String email, [
  String motDePasse = 'motdepasse',
]) async {
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.enterText(find.byType(TextField).at(1), motDePasse);
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle();
}

void main() {
  // Préférences de l'app simulées ; l'indice des gestes déjà vu (#64).
  setUp(() {
    SharedPreferences.setMockInitialValues({cleIndiceGestes: true});
    reinitialiserIndice();
  });
  testWidgets(
    'connexion : ce qui manque est indiqué, le bouton n\'est jamais désactivé',
    (tester) async {
      await lancer(tester);
      expect(find.text('Espace pro'), findsOneWidget);
      final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(bouton.onPressed, isNotNull);

      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      expect(find.text('Indiquez une adresse e-mail valide.'), findsOneWidget);
      expect(find.text('Indiquez votre mot de passe.'), findsOneWidget);
      expect(auth.appels, isEmpty);
    },
  );

  testWidgets(
    'mauvais mot de passe : message clair, on reste sur la connexion',
    (tester) async {
      await lancer(tester);
      await seConnecter(tester, 'amira@salon.test', 'faux');
      expect(find.text('E-mail ou mot de passe incorrect.'), findsOneWidget);
      expect(find.text('Espace pro'), findsOneWidget);
    },
  );

  testWidgets("Entrée : de l'e-mail au mot de passe, puis connexion", (
    tester,
  ) async {
    await lancer(tester);
    await tester.tap(find.byType(TextField).at(0));
    await tester.enterText(find.byType(TextField).at(0), 'amira@salon.test');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final motDePasse = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(motDePasse.focusNode!.hasFocus, isTrue);

    await tester.enterText(find.byType(TextField).at(1), 'motdepasse');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('Espace coiffeur'), findsOneWidget);
  });

  testWidgets('connexion : clavier e-mail, autofill, bouton pleine largeur', (
    tester,
  ) async {
    await lancer(tester);
    final email = tester.widget<TextField>(find.byType(TextField).at(0));
    final motDePasse = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(email.keyboardType, TextInputType.emailAddress);
    expect(email.autofillHints, contains(AutofillHints.email));
    expect(motDePasse.autofillHints, [AutofillHints.password]);
    expect(motDePasse.obscureText, isTrue);
    expect(
      tester.getSize(find.byType(FilledButton)).width,
      tester.getSize(find.byType(TextField).at(0)).width,
    );
  });

  testWidgets("coiffeur : son espace, quatre onglets, sans bascule (#64)", (
    tester,
  ) async {
    await lancer(tester);
    await seConnecter(tester, 'amira@salon.test');
    expect(find.textContaining('Espace coiffeur'), findsOneWidget);
    expect(find.text('Bonjour Amira'), findsOneWidget);
    expect(find.text("1 client aujourd'hui"), findsOneWidget);
    for (final onglet in ['Accueil', 'Planning', 'Salon', 'Compte']) {
      expect(
        find.widgetWithText(NavigationDestination, onglet),
        findsOneWidget,
      );
    }

    await ouvrirOnglet(tester, 'Salon');
    expect(find.text('Mes horaires'), findsOneWidget);
    expect(find.text('Prestations'), findsNothing);

    await ouvrirOnglet(tester, 'Compte');
    expect(find.text('Connecté avec'), findsOneWidget);
    expect(find.text('amira@salon.test'), findsOneWidget);
    expect(find.text('Coiffeur'), findsOneWidget);
    expect(find.byType(SegmentedButton<Espace>), findsNothing);
  });

  testWidgets('gérant (et client) : espace gérant seulement', (tester) async {
    await lancer(tester);
    await seConnecter(tester, 'gerant@salon.test');
    expect(find.textContaining('Espace gérant'), findsOneWidget);
    expect(find.text('encaissé'), findsOneWidget);

    await ouvrirOnglet(tester, 'Salon');
    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Prestations'), findsOneWidget);
    expect(find.text('Équipe'), findsOneWidget);

    await ouvrirOnglet(tester, 'Compte');
    expect(find.text('Gérant'), findsOneWidget);
    expect(find.byType(SegmentedButton<Espace>), findsNothing);
  });

  testWidgets(
    'gérant et coiffeur : choix de l\'espace, puis bascule dans les deux sens (onglet Compte)',
    (tester) async {
      await lancer(tester);
      await seConnecter(tester, 'patron@salon.test');
      expect(find.text('Choisir un espace'), findsOneWidget);

      await tester.tap(find.text('Espace gérant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Espace gérant'), findsOneWidget);

      await ouvrirOnglet(tester, 'Compte');
      expect(find.text('Gérant et coiffeur'), findsOneWidget);
      await tester.tap(find.text('Coiffeur'));
      await tester.pumpAndSettle();
      // Nouvel espace : retour sur « Accueil ».
      expect(find.textContaining('Espace coiffeur'), findsOneWidget);

      await ouvrirOnglet(tester, 'Compte');
      await tester.tap(find.text('Gérant'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Espace gérant'), findsOneWidget);
    },
  );

  testWidgets(
    '360 × 640 : barre d\'onglets visible sans défiler ; bascule et déconnexion dans « Compte »',
    (tester) async {
      petitEcran(tester);
      await lancer(tester);
      await seConnecter(tester, 'patron@salon.test');
      await tester.tap(find.text('Espace gérant'));
      await tester.pumpAndSettle();

      for (final onglet in ['Accueil', 'Planning', 'Salon', 'Compte']) {
        visibleSansDefiler(
          tester,
          find.widgetWithText(NavigationDestination, onglet),
        );
      }
      await ouvrirOnglet(tester, 'Compte');
      visibleSansDefiler(tester, find.byType(SegmentedButton<Espace>));
      visibleSansDefiler(tester, find.text('Se déconnecter'));
    },
  );

  testWidgets('logo « Salon RDV » : connexion, puis onglet Compte', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    await lancer(tester);
    expect(find.bySemanticsLabel('Salon RDV'), findsOneWidget);
    // Sur la connexion, le logo est en grand, sans barre du haut.
    expect(find.byType(AppBar), findsNothing);

    await seConnecter(tester, 'gerant@salon.test');
    await ouvrirOnglet(tester, 'Compte');
    expect(find.bySemanticsLabel('Salon RDV'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('simple client : accès refusé, déconnexion', (tester) async {
    await lancer(tester);
    await seConnecter(tester, 'client@salon.test');
    expect(find.text('Accès réservé à l\'équipe'), findsOneWidget);
    expect(find.textContaining('Espace gérant'), findsNothing);
    expect(find.textContaining('Espace coiffeur'), findsNothing);

    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Espace pro'), findsOneWidget);
    expect(auth.compte, isNull);
  });

  testWidgets('rôles illisibles : message et « Réessayer »', (tester) async {
    await lancer(tester);
    roles.enPanne = true;
    await seConnecter(tester, 'amira@salon.test');
    expect(find.text('Impossible de lire vos accès.'), findsOneWidget);

    roles.enPanne = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Espace coiffeur'), findsOneWidget);
  });

  testWidgets(
    'déconnexion depuis un espace (onglet Compte) : retour à la connexion',
    (tester) async {
      await lancer(tester);
      await seConnecter(tester, 'amira@salon.test');
      await ouvrirOnglet(tester, 'Compte');
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(find.text('Espace pro'), findsOneWidget);
      expect(auth.compte, isNull);
    },
  );
}
