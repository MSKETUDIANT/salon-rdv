import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:salon_pro/ui/composants.dart';

// Le libellé du champ est porté par le nœud du champ lui-même : c'est lui que
// le pont d'accessibilité transmet à TalkBack (Android) et au web.

Future<void> afficher(WidgetTester tester, Widget champ) => tester.pumpWidget(
  MaterialApp(
    theme: themeCharte(),
    home: Scaffold(body: champ),
  ),
);

SemanticsData noeudDuChamp(WidgetTester tester) =>
    tester.getSemantics(find.byType(EditableText)).getSemanticsData();

void main() {
  testWidgets(
    'Champ : nœud « champ de texte » libellé, vide ou rempli, lu une seule fois',
    (tester) async {
      final handle = tester.ensureSemantics();
      await afficher(
        tester,
        Champ(
          libelle: 'E-mail',
          controleur: TextEditingController(text: 'a@b.tn'),
        ),
      );

      expect(
        tester.getSemantics(find.byType(EditableText)),
        matchesSemantics(
          label: 'E-mail',
          value: 'a@b.tn',
          isTextField: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(find.bySemanticsLabel('E-mail'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(noeudDuChamp(tester).label, 'E-mail');
      handle.dispose();
    },
  );

  testWidgets('Champ en erreur : le message est lu', (tester) async {
    final handle = tester.ensureSemantics();
    await afficher(
      tester,
      Champ(
        libelle: 'E-mail',
        controleur: TextEditingController(),
        erreur: 'Indiquez une adresse e-mail valide.',
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('Indiquez une adresse e-mail valide')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets(
    'Mot de passe : masqué, bouton œil distinct pour afficher puis masquer',
    (tester) async {
      final handle = tester.ensureSemantics();
      await afficher(
        tester,
        Champ(
          libelle: 'Mot de passe',
          controleur: TextEditingController(text: 'secret'),
          motDePasse: true,
        ),
      );

      TextField champ() => tester.widget<TextField>(find.byType(TextField));
      expect(champ().obscureText, isTrue);
      expect(noeudDuChamp(tester).label, 'Mot de passe');

      // Bouton à part entière (pas fusionné dans le champ), zone tactile de 48 px.
      final oeil = find.byTooltip('Afficher le mot de passe');
      expect(
        tester.getSemantics(oeil),
        matchesSemantics(
          tooltip: 'Afficher le mot de passe',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSize(find.byType(IconButton)).height,
        greaterThanOrEqualTo(zoneTactileMin),
      );

      await tester.tap(oeil);
      await tester.pump();
      expect(champ().obscureText, isFalse);
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);

      await tester.tap(find.byTooltip('Masquer le mot de passe'));
      await tester.pump();
      expect(champ().obscureText, isTrue);
      handle.dispose();
    },
  );
}
