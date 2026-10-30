import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pro/data/planning.dart';
import 'package:salon_pro/features/planning/elements_planning.dart';
import 'package:salon_pro/ui/charte.dart';

// La charte de l'app pro est celle du site : mêmes jetons que
// web/app/globals.css, mêmes seuils de contraste (docs/charte-graphique.md §2).

double contraste(Color a, Color b) {
  final (claire, sombre) = a.computeLuminance() > b.computeLuminance()
      ? (a, b)
      : (b, a);
  return (claire.computeLuminance() + 0.05) /
      (sombre.computeLuminance() + 0.05);
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  test('mêmes couleurs que le site (web/app/globals.css)', () {
    final css = File('../web/app/globals.css').readAsStringSync();
    final jetons = {
      for (final m in RegExp(
        r'--color-([a-z-]+):\s*(#[0-9A-Fa-f]{6})',
      ).allMatches(css))
        m.group(1)!: m.group(2)!.toUpperCase(),
    };
    expect({
      'fond': hex(Couleurs.fond),
      'surface': hex(Couleurs.surface),
      'texte': hex(Couleurs.texte),
      'texte-secondaire': hex(Couleurs.texteSecondaire),
      'bordure': hex(Couleurs.bordure),
      'separateur': hex(Couleurs.separateur),
      'accent': hex(Couleurs.accent),
      'accent-survol': hex(Couleurs.accentSurvol),
      'erreur': hex(Couleurs.erreur),
    }, jetons);
  });

  test('mêmes tailles de texte que le site : 16 / 18 / 22 / 28 / 36 px', () {
    final css = File('../web/app/globals.css').readAsStringSync();
    final rem = [
      for (final m in RegExp(
        r'--text-[a-z0-9]+:\s*([\d.]+)rem',
      ).allMatches(css))
        double.parse(m.group(1)!) * 16,
    ];
    expect([
      Tailles.base,
      Tailles.lg,
      Tailles.xl,
      Tailles.x2l,
      Tailles.x3l,
    ], rem);
  });

  test('contrastes WCAG 2.2 AA (charte §2)', () {
    final couples = <(String, Color, Color, double)>[
      ('texte / fond', Couleurs.texte, Couleurs.fond, 4.5),
      ('texte / surface', Couleurs.texte, Couleurs.surface, 4.5),
      ('texte-secondaire / fond', Couleurs.texteSecondaire, Couleurs.fond, 4.5),
      (
        'texte-secondaire / surface',
        Couleurs.texteSecondaire,
        Couleurs.surface,
        4.5,
      ),
      ('bordure / fond', Couleurs.bordure, Couleurs.fond, 3),
      ('bordure / surface', Couleurs.bordure, Couleurs.surface, 3),
      ('accent / fond', Couleurs.accent, Couleurs.fond, 4.5),
      ('accent / surface', Couleurs.accent, Couleurs.surface, 4.5),
      ('erreur / fond', Couleurs.erreur, Couleurs.fond, 4.5),
      ('erreur / surface', Couleurs.erreur, Couleurs.surface, 4.5),
      ('blanc / accent', Couleurs.surface, Couleurs.accent, 4.5),
      ('blanc / accent-survol', Couleurs.surface, Couleurs.accentSurvol, 4.5),
      // Statuts d'un rendez-vous (#64).
      ('texte / terminé', Couleurs.texte, CouleursStatut.termineFond, 4.5),
      (
        'texte-secondaire / terminé',
        Couleurs.texteSecondaire,
        CouleursStatut.termineFond,
        4.5,
      ),
      ('texte / absent', Couleurs.texte, CouleursStatut.absentFond, 4.5),
      (
        'rouge absent / rose absent',
        CouleursStatut.absentTexte,
        CouleursStatut.absentFond,
        4.5,
      ),
      (
        'blanc / rouge absent',
        Couleurs.surface,
        CouleursStatut.absentTexte,
        4.5,
      ),
      ('texte / à clôturer', Couleurs.texte, CouleursStatut.aCloturerFond, 4.5),
      // Fonds révélés par les gestes, texte blanc.
      (
        'blanc / geste Terminé',
        Couleurs.surface,
        CouleursStatut.gesteTermine,
        4.5,
      ),
      (
        'blanc / geste Client absent',
        Couleurs.surface,
        CouleursStatut.gesteAbsent,
        4.5,
      ),
      (
        'ambre à clôturer / fond à clôturer',
        CouleursStatut.aCloturerTexte,
        CouleursStatut.aCloturerFond,
        4.5,
      ),
      (
        'bordure à clôturer / fond à clôturer',
        CouleursStatut.aCloturerBordure,
        CouleursStatut.aCloturerFond,
        3,
      ),
      (
        'bordure à clôturer / fond',
        CouleursStatut.aCloturerBordure,
        Couleurs.fond,
        3,
      ),
      (
        'erreur / fond (trait « maintenant »)',
        Couleurs.erreur,
        Couleurs.fond,
        3,
      ),
    ];
    for (final (nom, texte, fond, seuil) in couples) {
      expect(contraste(texte, fond), greaterThanOrEqualTo(seuil), reason: nom);
    }
  });

  test(
    'ThemeData : fond, accent, polices, boutons de 48 px, coins de 8 px, sans ombre',
    () {
      final theme = themeCharte();
      expect(theme.scaffoldBackgroundColor, Couleurs.fond);
      expect(theme.colorScheme.primary, Couleurs.accent);
      expect(theme.colorScheme.error, Couleurs.erreur);
      expect(theme.textTheme.headlineMedium!.fontFamily, policeTitre);
      expect(theme.textTheme.headlineMedium!.fontSize, Tailles.x2l);
      expect(theme.textTheme.bodyLarge!.fontFamily, policeTexte);
      expect(theme.textTheme.bodyLarge!.height, 1.5);

      final principal = theme.filledButtonTheme.style!;
      expect(principal.minimumSize!.resolve({}), const Size(44, 48));
      expect(principal.backgroundColor!.resolve({}), Couleurs.accent);
      expect(
        principal.backgroundColor!.resolve({WidgetState.hovered}),
        Couleurs.accentSurvol,
      );
      expect(
        principal.side!.resolve({WidgetState.focused}),
        const BorderSide(color: Couleurs.accent, width: 2),
      );
      expect(principal.elevation!.resolve({}), 0);

      final secondaire = theme.outlinedButtonTheme.style!;
      expect(
        secondaire.side!.resolve({}),
        const BorderSide(color: Couleurs.bordure),
      );
      expect(secondaire.backgroundColor!.resolve({}), Couleurs.surface);

      final champ = theme.inputDecorationTheme;
      expect(
        (champ.enabledBorder! as OutlineInputBorder).borderSide,
        const BorderSide(color: Couleurs.bordure, width: 1),
      );
      expect(
        (champ.errorBorder! as OutlineInputBorder).borderSide,
        const BorderSide(color: Couleurs.erreur, width: 2),
      );
      expect(
        (champ.focusedBorder! as OutlineInputBorder).borderRadius,
        BorderRadius.circular(8),
      );

      expect(theme.cardTheme.elevation, 0);
      expect(
        (theme.dialogTheme.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(8),
      );
      expect(theme.dialogTheme.backgroundColor, Couleurs.surface);
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    },
  );

  test(
    "états d'un rendez-vous : un fond différent par état, libellés écrits (#64, #102)",
    () {
      final styles = [for (final e in EtatRendezVous.values) StyleEtat.de(e)];
      expect(
        {for (final s in styles) s.fond}.length,
        EtatRendezVous.values.length,
      );
      // Les fonds des gestes ne sont celui d'aucun état.
      for (final geste in [
        CouleursStatut.gesteTermine,
        CouleursStatut.gesteAbsent,
      ]) {
        expect({for (final s in styles) s.fond}, isNot(contains(geste)));
      }
      expect(
        {for (final e in EtatRendezVous.values) e.libelle},
        {'À venir', 'Arrivé', 'En cours', 'À clôturer', 'Terminé', 'Absent'},
      );
      for (final e in EtatRendezVous.values) {
        final s = StyleEtat.de(e);
        expect(
          contraste(s.libelle, s.fond),
          greaterThanOrEqualTo(4.5),
          reason: e.libelle,
        );
        expect(
          contraste(s.texte, s.fond),
          greaterThanOrEqualTo(4.5),
          reason: e.libelle,
        );
      }
    },
  );
}
