import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Première connexion d'un coiffeur invité par le gérant (#145, option A de
// Sparta), depuis le lien de l'écran de connexion. Même parcours que « Mot de
// passe oublié » (#39) : étape 1, l'adresse de l'invitation, puis « Recevoir
// un code » ; étape 2, message neutre (jamais « pas d'invitation »), le code,
// le mot de passe choisi deux fois ; « Renvoyer le code » si besoin.
// Réussite : le compte est connecté ; la porte affiche son espace, ou « Accès
// réservé à l'équipe » sans invitation. Renvoie true.
// Les boutons ne sont jamais désactivés : ce qui manque est indiqué près du
// champ concerné.
class EcranPremiereConnexion extends StatefulWidget {
  const EcranPremiereConnexion({
    super.key,
    required this.auth,
    this.email = '',
  });

  final ServiceAuth auth;
  // E-mail déjà saisi sur l'écran de connexion.
  final String email;

  @override
  State<EcranPremiereConnexion> createState() => _EcranPremiereConnexionState();
}

// Même règle que le changement de mot de passe (#107).
const _longueurMinimale = 8;

class _EcranPremiereConnexionState extends State<EcranPremiereConnexion> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _motDePasse = TextEditingController();
  final _confirmation = TextEditingController();
  final _focusMotDePasse = FocusNode();
  final _focusConfirmation = FocusNode();
  bool _codeEnvoye = false;
  bool _enCours = false;
  String? _erreurEmail;
  String? _erreurCode;
  String? _erreurMotDePasse;
  String? _erreurConfirmation;
  String? _erreur;
  // Message après « Renvoyer le code ».
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _motDePasse.dispose();
    _confirmation.dispose();
    _focusMotDePasse.dispose();
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
    final erreur = await widget.auth.envoyerCodePremiereConnexion(email);
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

  Future<void> _creer() async {
    final code = _code.text.trim();
    final motDePasse = _motDePasse.text;
    setState(() {
      _erreur = null;
      _info = null;
      _erreurCode = RegExp(r'^\d{6}$').hasMatch(code)
          ? null
          : 'Le code a 6 chiffres.';
      _erreurMotDePasse = motDePasse.length < _longueurMinimale
          ? 'Au moins $_longueurMinimale caractères.'
          : null;
      _erreurConfirmation = _confirmation.text != motDePasse
          ? 'Les deux mots de passe ne sont pas identiques.'
          : null;
    });
    if (_erreurCode != null ||
        _erreurMotDePasse != null ||
        _erreurConfirmation != null) {
      return;
    }

    setState(() => _enCours = true);
    final erreur = await widget.auth.creerAcces(
      _email.text.trim(),
      code,
      motDePasse,
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
          _erreurMotDePasse = erreur.message;
        default:
          _erreur = erreur.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Première connexion')),
      body: AutofillGroup(
        child: ListeCharte(
          enfants: [
            if (!_codeEnvoye) ...[
              Text(
                // Espaces insécables : « à 6 chiffres » ne se coupe pas.
                'Votre gérant vous a ajouté à l\'équipe ? Saisissez '
                'l\'adresse e-mail de l\'invitation : vous recevrez un code '
                'à 6 chiffres pour créer votre mot de passe.',
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
              Semantics(
                liveRegion: true,
                child: Text(
                  // « cette adresse » plutôt que l'adresse, qui se couperait
                  // au milieu.
                  'Un e-mail vient d\'être envoyé à cette adresse avec un '
                  'code à 6 chiffres.',
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
                surValidation: _focusMotDePasse.requestFocus,
              ),
              const SizedBox(height: Espaces.s4),
              Champ(
                libelle: 'Choisissez un mot de passe',
                controleur: _motDePasse,
                focus: _focusMotDePasse,
                erreur: _erreurMotDePasse,
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
                surValidation: _creer,
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
              libelle: _codeEnvoye ? 'Créer mon accès' : 'Recevoir un code',
              libelleChargement: _codeEnvoye ? 'Création…' : 'Envoi…',
              chargement: _enCours,
              surAppui: _codeEnvoye ? _creer : _envoyer,
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
