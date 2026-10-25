import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/ui/charte.dart';
import 'package:salon_pro/ui/composants.dart';

// Le libellé du champ est porté par le nœud du champ lui-même : c'est lui que
// le pont d'accessibilité transmet à TalkBack (Android) et au web.
void main() {
  testWidgets(
    'Champ : nœud « champ de texte » libellé, libellé lu une seule fois',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: themeCharte(),
          home: Scaffold(
            body: Champ(
              libelle: 'E-mail',
              controleur: TextEditingController(text: 'a@b.tn'),
            ),
          ),
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

      // Vide aussi.
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
        'E-mail',
      );
      handle.dispose();
    },
  );
}
