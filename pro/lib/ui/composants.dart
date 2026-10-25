import 'package:flutter/material.dart';

import 'charte.dart';

// Composants de base de la charte (§4), équivalents de web/components/ui/.

// Champ de saisie : libellé toujours visible au-dessus du champ.
class Champ extends StatelessWidget {
  const Champ({
    super.key,
    required this.libelle,
    required this.controleur,
    this.erreur,
    this.motDePasse = false,
    this.clavier,
    this.autofill,
    this.actionClavier,
    this.surValidation,
  });

  final String libelle;
  final TextEditingController controleur;
  final String? erreur;
  final bool motDePasse;
  final TextInputType? clavier;
  final Iterable<String>? autofill;
  final TextInputAction? actionClavier;
  final VoidCallback? surValidation;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    // Libellé visible au-dessus du champ (charte §4), fusionné avec le champ
    // en un seul nœud d'accessibilité : TalkBack et les lecteurs d'écran du web
    // annoncent « E-mail, champ de texte », vide ou rempli
    // (test/ui/champ_semantique_test.dart).
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(libelle, style: textes.labelLarge),
          const SizedBox(height: Espaces.s2),
          TextField(
            controller: controleur,
            obscureText: motDePasse,
            keyboardType: clavier,
            autofillHints: autofill,
            autocorrect: false,
            enableSuggestions: !motDePasse,
            textInputAction: actionClavier,
            onSubmitted: surValidation == null ? null : (_) => surValidation!(),
            style: textes.bodyLarge,
            decoration: InputDecoration(errorText: erreur),
          ),
        ],
      ),
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
  });

  final String libelle;
  final VoidCallback surAppui;
  final bool chargement;
  final String libelleChargement;
  final bool secondaire;

  @override
  Widget build(BuildContext context) {
    void appui() {
      if (!chargement) surAppui();
    }

    final contenu = Text(chargement ? libelleChargement : libelle);
    return Semantics(
      // Équivalent de aria-busy.
      liveRegion: chargement,
      child: secondaire
          ? OutlinedButton(onPressed: appui, child: contenu)
          : FilledButton(onPressed: appui, child: contenu),
    );
  }
}

// Mise en page d'un écran : fond uni, colonne de 672 px au plus (max-w-2xl du
// site), marges de 16 px, défilement si le contenu dépasse.
class PageCharte extends StatelessWidget {
  const PageCharte({super.key, required this.enfants, this.actions = const []});

  final List<Widget> enfants;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: actions.isEmpty ? null : AppBar(actions: actions),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Espaces.s4,
            vertical: Espaces.s8,
          ),
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
      ),
    );
  }
}
