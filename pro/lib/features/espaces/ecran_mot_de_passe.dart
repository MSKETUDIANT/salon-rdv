import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Changer de mot de passe (#107), depuis la ligne « Mot de passe » du profil :
// mot de passe actuel, puis le nouveau (8 caractères au moins, bouton pour
// l'afficher). « Enregistrer » n'est jamais désactivé : au clic, ce qui manque
// est indiqué près du champ concerné, comme à la connexion. Renvoie true si
// le mot de passe est changé ; la session reste ouverte.
class EcranMotDePasse extends StatefulWidget {
  const EcranMotDePasse({super.key, required this.changer});

  final Future<ErreurMotDePasse?> Function(String actuel, String nouveau)
  changer;

  @override
  State<EcranMotDePasse> createState() => _EcranMotDePasseState();
}

// Longueur minimale : au moins celle de Supabase Auth (6 en local).
const longueurMotDePasse = 8;

class _EcranMotDePasseState extends State<EcranMotDePasse> {
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  final _focusNouveau = FocusNode();
  String? _erreurActuel;
  String? _erreurNouveau;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    _focusNouveau.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final actuel = _actuel.text;
    final nouveau = _nouveau.text;
    setState(() {
      _erreur = null;
      _erreurActuel = actuel.isEmpty
          ? 'Indiquez votre mot de passe actuel.'
          : null;
      _erreurNouveau = nouveau.length < longueurMotDePasse
          ? 'Au moins $longueurMotDePasse caractères.'
          : nouveau == actuel
          ? ErreurMotDePasse.identique.message
          : null;
    });
    if (_erreurActuel != null || _erreurNouveau != null) return;

    setState(() => _enCours = true);
    final erreur = await widget.changer(actuel, nouveau);
    if (!mounted) return;
    if (erreur == null) {
      // Le système propose de mettre à jour le mot de passe enregistré.
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _enCours = false;
      switch (erreur) {
        case ErreurMotDePasse.actuelIncorrect:
          _erreurActuel = erreur.message;
        case ErreurMotDePasse.tropFaible || ErreurMotDePasse.identique:
          _erreurNouveau = erreur.message;
        default:
          _erreur = erreur.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe')),
      body: AutofillGroup(
        child: ListeCharte(
          enfants: [
            Champ(
              libelle: 'Mot de passe actuel',
              controleur: _actuel,
              erreur: _erreurActuel,
              motDePasse: true,
              autofill: const [AutofillHints.password],
              actionClavier: TextInputAction.next,
              surValidation: _focusNouveau.requestFocus,
            ),
            const SizedBox(height: Espaces.s4),
            Champ(
              libelle: 'Nouveau mot de passe',
              controleur: _nouveau,
              focus: _focusNouveau,
              erreur: _erreurNouveau,
              aide: '$longueurMotDePasse caractères au moins.',
              motDePasse: true,
              autofill: const [AutofillHints.newPassword],
              actionClavier: TextInputAction.done,
              surValidation: _enregistrer,
            ),
            const SizedBox(height: Espaces.s6),
            if (_erreur != null) ...[
              MessageErreur(_erreur!),
              const SizedBox(height: Espaces.s3),
            ],
            Bouton(
              libelle: 'Enregistrer',
              libelleChargement: 'Enregistrement…',
              chargement: _enCours,
              pleineLargeur: true,
              surAppui: _enregistrer,
            ),
          ],
        ),
      ),
    );
  }
}
