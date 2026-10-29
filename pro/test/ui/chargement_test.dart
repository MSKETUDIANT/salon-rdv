import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/salon.dart';
import 'package:salon_pro/ui/chargement.dart';
import 'package:salon_pro/ui/charte.dart';

void main() {
  testWidgets('Chargement : erreur, puis « Réessayer » affiche les données', (
    tester,
  ) async {
    var echec = true;
    var appels = 0;
    Future<String> lire() async {
      appels++;
      if (echec) throw const ErreurSalon('Lecture impossible.');
      return 'Données';
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: themeCharte(),
        home: Scaffold(
          body: Chargement<String>(
            lire: lire,
            afficher: (context, texte, _) => Text(texte),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lecture impossible.'), findsOneWidget);

    echec = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(appels, 2);
    expect(find.text('Données'), findsOneWidget);
  });

  testWidgets('pendant la lecture : silhouettes, pas de roue (#83)', (
    tester,
  ) async {
    final lecture = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        theme: themeCharte(),
        home: Scaffold(
          body: Chargement<String>(
            lire: () => lecture.future,
            afficher: (context, texte, _) => Text(texte),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SilhouetteListe), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Chargement'), findsOneWidget);
    lecture.complete('Données');
    await tester.pumpAndSettle();
    expect(find.byType(SilhouetteListe), findsNothing);
    expect(find.text('Données'), findsOneWidget);
  });

  testWidgets('erreur hors base : message sans réseau, jamais technique', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: themeCharte(),
        home: Scaffold(
          body: Chargement<String>(
            lire: () async => throw TimeoutException('délai'),
            afficher: (context, texte, _) => Text(texte),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(messageHorsReseau), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
  });
}
