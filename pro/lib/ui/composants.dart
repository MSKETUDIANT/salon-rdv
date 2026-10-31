import 'package:flutter/material.dart';

import 'charte.dart';
import 'marque.dart';

// Composants de base de la charte (§4), équivalents de web/components/ui/.

// Champ de saisie : libellé toujours visible au-dessus du champ, aide (format
// attendu, exemple) dessous, remplacée par le message d'erreur s'il y en a un
// (charte §11). Un champ mot de passe a un bouton pour afficher ou masquer la
// saisie.
class Champ extends StatefulWidget {
  const Champ({
    super.key,
    required this.libelle,
    required this.controleur,
    this.erreur,
    this.aide,
    this.motDePasse = false,
    this.clavier,
    this.autofill,
    this.actionClavier,
    this.surValidation,
    this.focus,
    this.capitalisation = TextCapitalization.none,
  });

  final String libelle;
  final TextEditingController controleur;
  final String? erreur;
  // « Exemple : 35 ou 10,500 ».
  final String? aide;
  final bool motDePasse;
  final TextInputType? clavier;
  final Iterable<String>? autofill;
  final TextInputAction? actionClavier;
  // Touche Entrée (ou action du clavier) : champ suivant, ou validation.
  final VoidCallback? surValidation;
  final FocusNode? focus;
  // Nom, motif : majuscule en début de phrase sur le clavier du téléphone.
  final TextCapitalization capitalisation;

  @override
  State<Champ> createState() => _ChampState();
}

class _ChampState extends State<Champ> {
  late bool _masque = widget.motDePasse;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final surValidation = widget.surValidation;
    // Le libellé visible (exclu de l'accessibilité) est repris sur le nœud du
    // champ : TalkBack et les lecteurs d'écran du web annoncent « E-mail,
    // champ de texte », vide ou rempli, puis le message d'erreur ; le bouton
    // œil reste un bouton distinct (test/ui/champ_semantique_test.dart).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Text(widget.libelle, style: textes.labelLarge)),
        const SizedBox(height: Espaces.s2),
        Semantics(
          label: widget.libelle,
          child: TextField(
            controller: widget.controleur,
            focusNode: widget.focus,
            obscureText: _masque,
            keyboardType: widget.clavier,
            textCapitalization: widget.capitalisation,
            autofillHints: widget.autofill,
            autocorrect: false,
            enableSuggestions: !widget.motDePasse,
            textInputAction: widget.actionClavier,
            onSubmitted: surValidation == null ? null : (_) => surValidation(),
            style: textes.bodyLarge,
            decoration: InputDecoration(
              errorText: widget.erreur,
              helperText: widget.aide,
              suffixIcon: widget.motDePasse
                  ? IconButton(
                      onPressed: () => setState(() => _masque = !_masque),
                      tooltip: _masque
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      icon: Icon(
                        _masque
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Couleurs.texteSecondaire,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// Bouton principal. Pas de bouton désactivé : pendant le chargement, il reste
// focusable mais ignore les appuis, avec un libellé de chargement (charte §4).
class Bouton extends StatelessWidget {
  const Bouton({
    super.key,
    required this.libelle,
    required this.surAppui,
    this.chargement = false,
    this.libelleChargement = 'Chargement…',
    this.secondaire = false,
    this.pleineLargeur = false,
  });

  final String libelle;
  final VoidCallback surAppui;
  final bool chargement;
  final String libelleChargement;
  final bool secondaire;
  final bool pleineLargeur;

  @override
  Widget build(BuildContext context) {
    void appui() {
      if (!chargement) surAppui();
    }

    final contenu = Text(chargement ? libelleChargement : libelle);
    final bouton = Semantics(
      // Équivalent de aria-busy.
      liveRegion: chargement,
      child: secondaire
          ? OutlinedButton(onPressed: appui, child: contenu)
          : FilledButton(onPressed: appui, child: contenu),
    );
    return pleineLargeur
        ? SizedBox(width: double.infinity, child: bouton)
        : bouton;
  }
}

// Écran de premier niveau (accueil d'un espace, choix d'espace, accès
// refusé) : barre du haut avec le logo et ses actions (menu du compte), fond
// uni, colonne de 672 px au plus (max-w-2xl du site), marges de 16 px,
// défilement si le contenu dépasse. Sans logo ni action (connexion, qui
// affiche le logo en grand) : pas de barre.
class PageCharte extends StatelessWidget {
  const PageCharte({
    super.key,
    required this.enfants,
    this.actions = const [],
    this.logo = true,
  });

  final List<Widget> enfants;
  final List<Widget> actions;
  final bool logo;

  @override
  Widget build(BuildContext context) {
    final barre = logo || actions.isNotEmpty;
    return Scaffold(
      appBar: barre
          ? AppBar(
              title: logo ? const LogoSalonRdv() : null,
              actions: [
                ...actions,
                const SizedBox(width: Espaces.s1),
              ],
            )
          : null,
      body: ListeCharte(
        enfants: enfants,
        haut: barre ? Espaces.s4 : Espaces.s8,
      ),
    );
  }
}

// Corps défilant d'un écran, pour les écrans qui ont leur propre barre de
// titre (retour) : mêmes marges et même largeur que PageCharte.
class ListeCharte extends StatelessWidget {
  const ListeCharte({super.key, required this.enfants, this.haut = Espaces.s4});

  final List<Widget> enfants;
  final double haut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Espaces.s4, haut, Espaces.s4, Espaces.s8),
        // Toute la largeur disponible jusqu'à 672 px, même quand le contenu
        // est étroit : le texte reste aligné à gauche, comme sur le site.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: enfants,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Entrée de menu : carte entière cliquable (bordure `bordure`, charte §4),
// titre, description et chevron.
class CarteLien extends StatelessWidget {
  const CarteLien({
    super.key,
    required this.titre,
    required this.description,
    required this.surAppui,
  });

  final String titre;
  final String description;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: Material(
        color: Couleurs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rayon),
          side: const BorderSide(color: Couleurs.bordure),
        ),
        child: InkWell(
          onTap: surAppui,
          borderRadius: BorderRadius.circular(rayon),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: zoneTactileMin),
            child: Padding(
              padding: const EdgeInsets.all(Espaces.s4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre, style: textes.titleMedium),
                        const SizedBox(height: Espaces.s1),
                        Text(description, style: textes.bodySmall),
                      ],
                    ),
                  ),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: Couleurs.texteSecondaire,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Initiale d'un nom (#72) : une seule lettre partout, pour que tous les
// avatars se ressemblent (#73) : « Amira Ben Salah » → « A ».
String initiales(String nom) {
  final premier = nom.trim();
  return premier.isEmpty ? '' : premier.characters.first.toUpperCase();
}

// Version affichée dans le profil (#73) ; tenue égale à celle de pubspec.yaml
// par test/ui/version_test.dart.
const versionApp = '0.5.0';

// Avatar rond (#72) : initiales sur fond `separateur`, faute de photo.
// Décoratif : le nom est toujours écrit à côté ou dans le libellé du parent.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.nom, this.taille = 48});

  final String nom;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: taille,
        height: taille,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Couleurs.separateur,
          shape: BoxShape.circle,
        ),
        child: Text(
          initiales(nom),
          style: taille >= 72
              ? Theme.of(context).textTheme.headlineMedium!.copyWith(height: 1)
              : Theme.of(context).textTheme.labelLarge!.copyWith(height: 1),
        ),
      ),
    );
  }
}
