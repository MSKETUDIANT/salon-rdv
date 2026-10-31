import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Mot de passe oublié (#39, code à 6 chiffres décidé par Sparta), depuis le
// lien de l'écran de connexion. Étape 1 : l'e-mail, puis « Recevoir un code ».
// Étape 2 : message neutre (jamais « compte inconnu »), le code, le nouveau
// mot de passe deux fois ; « Renvoyer le code » si besoin. Réussite : le
// compte est connecté, la porte affiche son espace ; renvoie true.
// Comme à la connexion, les boutons ne sont jamais désactivés : ce qui manque
// est indiqué près du champ concerné.
class EcranMotDePasseOublie extends StatefulWidget {
  const EcranMotDePasseOublie({super.key, required this.auth, this.email = ''});

  final ServiceAuth auth;
  // E-mail déjà saisi sur l'écran de connexion.
  final String email;

  @override
  State<EcranMotDePasseOublie> createState() => _EcranMotDePasseOublieState();
}

// Même règle que le changement de mot de passe (#107).
const _longueurMinimale = 8;

class _EcranMotDePasseOublieState extends State<EcranMotDePasseOublie> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  final _focusNouveau = FocusNode();
  final _focusConfirmation = FocusNode();
  bool _codeEnvoye = false;
  bool _enCours = false;
  String? _erreurEmail;
  String? _erreurCode;
  String? _erreurNouveau;
  String? _erreurConfirmation;
  String? _erreur;
  // Message après « Renvoyer le code ».
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    _focusNouveau.dispose();
    _focusConfirmation.dispose();
    super.dispose();
  }

  Future<void> _envoyer({bool renvoi = false}) async {
    final email = _email.text.trim();
    setState(() {
      _erreur = null;
      _info = null;
      _erreurEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
          ? null
          : 'Indiquez une adresse e-mail valide.';
    });
    if (_erreurEmail != null) return;

    setState(() => _enCours = true);
    final erreur = await widget.auth.envoyerCodeOubli(email);
    if (!mounted) return;
    setState(() {
      _enCours = false;
      if (erreur != null) {
        _erreur = erreur.message;
      } else {
        _codeEnvoye = true;
        if (renvoi) _info = 'Nouveau code envoyé.';
      }
    });
  }

  Future<void> _changer() async {
    final code = _code.text.trim();
    final nouveau = _nouveau.text;
    setState(() {
      _erreur = null;
      _info = null;
      _erreurCode = RegExp(r'^\d{6}$').hasMatch(code)
          ? null
          : 'Le code a 6 chiffres.';
      _erreurNouveau = nouveau.length < _longueurMinimale
          ? 'Au moins $_longueurMinimale caractères.'
          : null;
      _erreurConfirmation = _confirmation.text != nouveau
          ? 'Les deux mots de passe ne sont pas identiques.'
          : null;
    });
    if (_erreurCode != null ||
        _erreurNouveau != null ||
        _erreurConfirmation != null) {
      return;
    }

    setState(() => _enCours = true);
    final erreur = await widget.auth.reinitialiserMotDePasse(
      _email.text.trim(),
      code,
      nouveau,
    );
    if (!mounted) return;
    if (erreur == null) {
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _enCours = false;
      switch (erreur) {
        case ErreurOubli.codeInvalide:
          _erreurCode = erreur.message;
        case ErreurOubli.tropFaible:
          _erreurNouveau = erreur.message;
        default:
          _erreur = erreur.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: AutofillGroup(
        child: ListeCharte(
          enfants: [
            if (!_codeEnvoye) ...[
              Text(
                // Espaces insécables : « à 6 chiffres » ne se coupe pas.
                'Saisissez l\'e-mail de votre compte : vous recevrez un code '
                'à 6 chiffres.',
                style: textes.bodyLarge,
              ),
              const SizedBox(height: Espaces.s6),
              Champ(
                libelle: 'E-mail',
                controleur: _email,
                erreur: _erreurEmail,
                clavier: TextInputType.emailAddress,
                autofill: const [AutofillHints.email, AutofillHints.username],
                actionClavier: TextInputAction.done,
                surValidation: _envoyer,
              ),
            ] else ...[
              // Neutre : ne dit jamais si l'adresse a un compte.
              Semantics(
                liveRegion: true,
                child: Text(
                  // « cette adresse » plutôt que l'adresse elle-même, qui
                  // se couperait au milieu (au tiret, par exemple).
                  'Si un compte existe pour cette adresse, un e-mail vient '
                  'd\'être envoyé avec un code à 6 chiffres.',
                  style: textes.bodyLarge,
                ),
              ),
              const SizedBox(height: Espaces.s6),
              Champ(
                libelle: 'Code reçu par e-mail',
                controleur: _code,
                erreur: _erreurCode,
                clavier: TextInputType.number,
                autofill: const [AutofillHints.oneTimeCode],
                actionClavier: TextInputAction.next,
                surValidation: _focusNouveau.requestFocus,
              ),
              const SizedBox(height: Espaces.s4),
              Champ(
                libelle: 'Nouveau mot de passe',
                controleur: _nouveau,
                focus: _focusNouveau,
                erreur: _erreurNouveau,
                aide: '$_longueurMinimale caractères au moins.',
                motDePasse: true,
                autofill: const [AutofillHints.newPassword],
                actionClavier: TextInputAction.next,
                surValidation: _focusConfirmation.requestFocus,
              ),
              const SizedBox(height: Espaces.s4),
              Champ(
                libelle: 'Confirmer le mot de passe',
                controleur: _confirmation,
                focus: _focusConfirmation,
                erreur: _erreurConfirmation,
                motDePasse: true,
                autofill: const [AutofillHints.newPassword],
                actionClavier: TextInputAction.done,
                surValidation: _changer,
              ),
            ],
            const SizedBox(height: Espaces.s6),
            if (_erreur != null || _info != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  _erreur ?? _info!,
                  style: textes.bodyLarge!.copyWith(
                    color: _erreur != null ? Couleurs.erreur : Couleurs.texte,
                  ),
                ),
              ),
              const SizedBox(height: Espaces.s3),
            ],
            Bouton(
              pleineLargeur: true,
              libelle: _codeEnvoye
                  ? 'Changer le mot de passe'
                  : 'Recevoir un code',
              libelleChargement: _codeEnvoye ? 'Enregistrement…' : 'Envoi…',
              chargement: _enCours,
              surAppui: _codeEnvoye ? _changer : _envoyer,
            ),
            if (_codeEnvoye) ...[
              const SizedBox(height: Espaces.s2),
              Center(
                child: TextButton(
                  onPressed: _enCours ? null : () => _envoyer(renvoi: true),
                  child: const Text('Renvoyer le code'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
