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
}
