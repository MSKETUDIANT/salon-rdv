import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/app.dart';
import 'package:salon_pro/data/session.dart';

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
  await tester.pumpWidget(AppPro(auth: auth, roles: roles, salon: FauxSalon()));
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
    expect(find.text('Espace coiffeur'), findsOneWidget);
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

  testWidgets('coiffeur : directement dans son espace, sans bascule', (
    tester,
  ) async {
    await lancer(tester);
    await seConnecter(tester, 'amira@salon.test');
    expect(find.text('Espace coiffeur'), findsOneWidget);
    expect(find.text('Connecté avec amira@salon.test'), findsOneWidget);
    expect(find.textContaining('Passer à'), findsNothing);
  });

  testWidgets('gérant (et client) : espace gérant seulement', (tester) async {
    await lancer(tester);
    await seConnecter(tester, 'gerant@salon.test');
    expect(find.text('Espace gérant'), findsOneWidget);
    expect(find.textContaining('Passer à'), findsNothing);
  });

  testWidgets(
    'gérant et coiffeur : choix de l\'espace, puis bascule dans les deux sens',
    (tester) async {
      await lancer(tester);
      await seConnecter(tester, 'patron@salon.test');
      expect(find.text('Choisir un espace'), findsOneWidget);

      await tester.tap(find.text('Espace gérant'));
      await tester.pumpAndSettle();
      expect(find.text('Espace gérant'), findsOneWidget);

      await tester.tap(find.text('Passer à l\'espace coiffeur'));
      await tester.pumpAndSettle();
      expect(find.text('Espace coiffeur'), findsOneWidget);

      await tester.tap(find.text('Passer à l\'espace gérant'));
      await tester.pumpAndSettle();
      expect(find.text('Espace gérant'), findsOneWidget);
    },
  );

  testWidgets('simple client : accès refusé, déconnexion', (tester) async {
    await lancer(tester);
    await seConnecter(tester, 'client@salon.test');
    expect(find.text('Accès réservé à l\'équipe'), findsOneWidget);
    expect(find.text('Espace gérant'), findsNothing);
    expect(find.text('Espace coiffeur'), findsNothing);

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
    expect(find.text('Espace coiffeur'), findsOneWidget);
  });

  testWidgets('déconnexion depuis un espace : retour à la connexion', (
    tester,
  ) async {
    await lancer(tester);
    await seConnecter(tester, 'amira@salon.test');
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.text('Espace pro'), findsOneWidget);
  });
}
