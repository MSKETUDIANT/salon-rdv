import 'package:flutter/material.dart';

// Charte graphique (docs/charte-graphique.md), la même que le site : jetons de
// web/app/globals.css traduits pour Flutter. Seule source des couleurs, tailles
// de texte, arrondis, espacements et polices de l'app pro. Mode clair
// uniquement en v1. Contrastes vérifiés par test/ui/charte_test.dart.

abstract final class Couleurs {
  static const fond = Color(0xFFFAFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const texte = Color(0xFF1A1A1A);
  static const texteSecondaire = Color(0xFF5C5C5C);
  static const bordure = Color(0xFF8A8A8A);
  static const separateur = Color(0xFFE5E3DE);
  static const accent = Color(0xFF1F5C4A);
  static const accentSurvol = Color(0xFF174536);
  static const erreur = Color(0xFFB42318);
}

// Statuts d'un rendez-vous (#64) : frise du planning, accueil,
// gestes. Dérivées de la charte ; le statut est toujours écrit aussi (jamais
// la couleur seule). Contrastes vérifiés par test/ui/charte_test.dart.
//   à venir : fond surface, bordure et libellé accent ;
//   en cours : fond accent, texte blanc ;
//   à clôturer : fond ambre pâle, bordure et libellé ambre foncé ;
//   terminé : fond gris clair, texte et libellé secondaire ;
//   absent : fond rose pâle, libellé rouge foncé.
// Gestes : vert foncé plein (« Terminé ») et rouge foncé plein (« Client
// absent »), texte blanc.
abstract final class CouleursStatut {
  static const termineFond = Color(0xFFEFEDE8);
  static const absentFond = Color(0xFFFBEAE8);
  static const absentTexte = Color(0xFF8F1D13);
  static const aCloturerFond = Color(0xFFFCEFD6);
  static const aCloturerBordure = Color(0xFFA35A00);
  static const aCloturerTexte = Color(0xFF8A4B00);
  // Fonds révélés par les gestes : couleurs d'action pleines et foncées,
  // distinctes des fonds des états (le vert, plus foncé que l'accent du
  // rendez-vous en cours), texte et icône blancs.
  static const gesteTermine = Color(0xFF0B3325);
  static const gesteAbsent = Color(0xFF7A1A10);
}

// Échelle typographique : 16 / 18 / 22 / 28 / 36 px, interligne 1,5.
abstract final class Tailles {
  static const base = 16.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const x2l = 28.0;
  static const x3l = 36.0;
}

// Espacements, sur la grille de 4 px du site (Tailwind : gap-2 = 8 px...).
abstract final class Espaces {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

// Coins de 8 px partout ; boutons de 48 px de haut, zones tactiles d'au moins
// 44 × 44 px.
const rayon = 8.0;
const hauteurBouton = 48.0;
const zoneTactileMin = 44.0;

const policeTitre = 'Newsreader';
const policeTexte = 'Figtree';

// Polices variables : la graisse passe par l'axe « wght » (fontWeight seul ne
// suffit pas à choisir l'instance).
TextStyle _style(String police, double taille, int graisse, Color couleur) =>
    TextStyle(
      fontFamily: police,
      fontSize: taille,
      height: 1.5,
      fontWeight: FontWeight.values[(graisse ~/ 100) - 1],
      fontVariations: [FontVariation.weight(graisse.toDouble())],
      color: couleur,
    );

// Titres en Newsreader 500 (font-titre font-medium), texte en Figtree 400,
// libellés et boutons en Figtree 600 (font-semibold).
final textes = TextTheme(
  displaySmall: _style(policeTitre, Tailles.x3l, 500, Couleurs.texte),
  headlineMedium: _style(policeTitre, Tailles.x2l, 500, Couleurs.texte),
  headlineSmall: _style(policeTitre, Tailles.xl, 500, Couleurs.texte),
  titleLarge: _style(policeTitre, Tailles.xl, 500, Couleurs.texte),
  titleMedium: _style(policeTexte, Tailles.lg, 600, Couleurs.texte),
  titleSmall: _style(policeTexte, Tailles.base, 600, Couleurs.texte),
  bodyLarge: _style(policeTexte, Tailles.base, 400, Couleurs.texte),
  bodyMedium: _style(policeTexte, Tailles.base, 400, Couleurs.texte),
  bodySmall: _style(policeTexte, Tailles.base, 400, Couleurs.texteSecondaire),
  labelLarge: _style(policeTexte, Tailles.base, 600, Couleurs.texte),
  labelMedium: _style(policeTexte, Tailles.base, 600, Couleurs.texte),
  labelSmall: _style(policeTexte, Tailles.base, 600, Couleurs.texteSecondaire),
);

final _formeBouton = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(rayon),
);
const _paddingBouton = EdgeInsets.symmetric(horizontal: 20);

// Focus clavier : contour accent de 2 px (charte §4).
WidgetStateProperty<BorderSide?> _contour(BorderSide? repos) =>
    WidgetStateProperty.resolveWith((etats) {
      if (etats.contains(WidgetState.focused)) {
        return const BorderSide(color: Couleurs.accent, width: 2);
      }
      return repos;
    });

OutlineInputBorder _bordureChamp(Color couleur, double largeur) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(rayon),
      borderSide: BorderSide(color: couleur, width: largeur),
    );

ThemeData themeCharte() {
  const schema = ColorScheme(
    brightness: Brightness.light,
    primary: Couleurs.accent,
    onPrimary: Couleurs.surface,
    secondary: Couleurs.accent,
    onSecondary: Couleurs.surface,
    error: Couleurs.erreur,
    onError: Couleurs.surface,
    surface: Couleurs.surface,
    onSurface: Couleurs.texte,
    onSurfaceVariant: Couleurs.texteSecondaire,
    outline: Couleurs.bordure,
    outlineVariant: Couleurs.separateur,
    // Pas de teinte ni d'ombre Material : bordure ou contraste fond/surface.
    surfaceTint: Colors.transparent,
    shadow: Colors.transparent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: schema,
    scaffoldBackgroundColor: Couleurs.fond,
    fontFamily: policeTexte,
    textTheme: textes,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    dividerTheme: const DividerThemeData(
      color: Couleurs.separateur,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Couleurs.fond,
      foregroundColor: Couleurs.texte,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textes.titleLarge,
    ),
    // Bouton principal : fond accent, texte blanc ; survol accent-survol.
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(zoneTactileMin, hauteurBouton),
        ),
        padding: const WidgetStatePropertyAll(_paddingBouton),
        shape: WidgetStatePropertyAll(_formeBouton),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(textes.labelLarge),
        foregroundColor: const WidgetStatePropertyAll(Couleurs.surface),
        backgroundColor: WidgetStateProperty.resolveWith(
          (etats) =>
              etats.contains(WidgetState.hovered) ||
                  etats.contains(WidgetState.pressed)
              ? Couleurs.accentSurvol
              : Couleurs.accent,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: _contour(null),
      ),
    ),
    // Bouton secondaire : fond surface, bordure `bordure`, texte `texte`.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(zoneTactileMin, hauteurBouton),
        ),
        padding: const WidgetStatePropertyAll(_paddingBouton),
        shape: WidgetStatePropertyAll(_formeBouton),
        textStyle: WidgetStatePropertyAll(textes.labelLarge),
        foregroundColor: const WidgetStatePropertyAll(Couleurs.texte),
        backgroundColor: WidgetStateProperty.resolveWith(
          (etats) =>
              etats.contains(WidgetState.hovered) ||
                  etats.contains(WidgetState.pressed)
              ? Couleurs.fond
              : Couleurs.surface,
        ),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        side: _contour(const BorderSide(color: Couleurs.bordure)),
      ),
    ),
    // Lien : texte accent souligné (« Changer de compte » sur le site).
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(zoneTactileMin, zoneTactileMin),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(_formeBouton),
        foregroundColor: const WidgetStatePropertyAll(Couleurs.accent),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStatePropertyAll(
          textes.labelLarge!.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: Couleurs.accent,
          ),
        ),
        side: _contour(null),
      ),
    ),
    // Champ : fond surface, bordure 1 px `bordure` ; focus accent 2 px ; en
    // erreur, bordure 2 px et message en `erreur`. Le libellé est affiché
    // au-dessus du champ (ui/composants.dart), jamais dans le champ.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Couleurs.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espaces.s4,
        vertical: Espaces.s3,
      ),
      hintStyle: textes.bodyMedium!.copyWith(color: Couleurs.texteSecondaire),
      errorStyle: textes.bodyMedium!.copyWith(color: Couleurs.erreur),
      errorMaxLines: 3,
      // Aide sous le champ (exemple de format) : texte secondaire, 16 px.
      helperStyle: textes.bodySmall,
      helperMaxLines: 3,
      border: _bordureChamp(Couleurs.bordure, 1),
      enabledBorder: _bordureChamp(Couleurs.bordure, 1),
      focusedBorder: _bordureChamp(Couleurs.accent, 2),
      errorBorder: _bordureChamp(Couleurs.erreur, 2),
      focusedErrorBorder: _bordureChamp(Couleurs.erreur, 2),
    ),
    // Carte : fond surface, coins 8 px, bordure `separateur`, sans ombre.
    cardTheme: CardThemeData(
      color: Couleurs.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rayon),
        side: const BorderSide(color: Couleurs.separateur),
      ),
    ),
    // Dialogue : surface, coins de 8 px (Material 3 en met 28), sans teinte.
    dialogTheme: DialogThemeData(
      backgroundColor: Couleurs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon)),
      titleTextStyle: textes.titleLarge,
      contentTextStyle: textes.bodyLarge,
    ),
    // Sélecteurs de date et d'heure : mêmes coins, sans teinte.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Couleurs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Couleurs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon)),
    ),
    // Barre d'onglets (#64), comme celle du site sur téléphone (charte §4) :
    // fond surface, onglet courant en accent et gras avec une pastille
    // `separateur` derrière l'icône, les autres en texte secondaire ;
    // libellés de 16 px.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Couleurs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: Couleurs.separateur,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (etats) => etats.contains(WidgetState.selected)
            ? textes.labelLarge!.copyWith(color: Couleurs.accent)
            : textes.bodyMedium!.copyWith(color: Couleurs.texteSecondaire),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (etats) => IconThemeData(
          color: etats.contains(WidgetState.selected)
              ? Couleurs.accent
              : Couleurs.texteSecondaire,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Couleurs.accent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Couleurs.texte,
      contentTextStyle: textes.bodyMedium!.copyWith(color: Couleurs.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rayon)),
      behavior: SnackBarBehavior.floating,
      // « Annuler » après un geste (#64) : blanc sur `texte`.
      actionTextColor: Couleurs.surface,
    ),
    // Pastilles de choix (coiffeur du planning, #64) : arrondi `pastille`,
    // choisie en accent et texte blanc, les autres en surface et bordure.
    chipTheme: ChipThemeData(
      backgroundColor: Couleurs.surface,
      selectedColor: Couleurs.accent,
      side: const BorderSide(color: Couleurs.bordure),
      shape: const StadiumBorder(),
      // Couleur du libellé : sur chaque pastille (blanc si choisie).
      labelStyle: textes.labelLarge,
      padding: const EdgeInsets.symmetric(
        horizontal: Espaces.s2,
        vertical: Espaces.s2,
      ),
    ),
  );
}
