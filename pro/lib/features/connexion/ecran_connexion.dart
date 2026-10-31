import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../../ui/marque.dart';
import 'ecran_recevoir_code.dart';

// Connexion de l'équipe : e-mail et mot de passe (comptes créés via #2).
// « Se connecter » n'est jamais désactivé : au clic, ce qui manque est indiqué
// près du champ concerné. Entrée passe de l'e-mail au mot de passe, puis
// valide. En cas d'échec, le message ne dit pas lequel des deux est faux, et
// propose de recevoir un code (#148). Un seul lien de secours, sous le mot de
// passe, pour le coiffeur invité (jamais de mot de passe) comme pour l'oubli.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key, required this.auth});

  final ServiceAuth auth;

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  final _focusMotDePasse = FocusNode();
  String? _erreurEmail;
  String? _erreurMotDePasse;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    _focusMotDePasse.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final email = _email.text.trim();
    setState(() {
      _erreur = null;
      _erreurEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
          ? null
          : 'Indiquez une adresse e-mail valide.';
      _erreurMotDePasse = _motDePasse.text.isEmpty
          ? 'Indiquez votre mot de passe.'
          : null;
    });
    if (_erreurEmail != null || _erreurMotDePasse != null) return;

    setState(() => _enCours = true);
    final erreur = await widget.auth.seConnecter(email, _motDePasse.text);
    if (!mounted) return;
    // Succès : le système propose d'enregistrer les identifiants (autofill).
    if (erreur == null) TextInput.finishAutofillContext();
    // En cas de succès, la porte (porte.dart) remplace cet écran.
    setState(() {
      _enCours = false;
      _erreur = erreur;
    });
  }

  // Code reçu par e-mail, puis mot de passe choisi (#148). Réussite : le
  // compte est connecté et la porte remplace cet écran par son espace.
  // Le message passe par le gestionnaire de messages de l'app, pris avant :
  // cet écran n'existe plus au retour (la porte l'a remplacé).
  Future<void> _recevoirCode() async {
    final messages = ScaffoldMessenger.of(context);
    final connecte = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EcranRecevoirCode(auth: widget.auth, email: _email.text.trim()),
      ),
    );
    if (connecte == true) {
      messages
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Mot de passe enregistré. Vous êtes connecté.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    // Logo en grand, sans barre du haut (#41).
    return PageCharte(
      logo: false,
      enfants: [
        const LogoSalonRdv(taille: Tailles.x3l),
        const SizedBox(height: Espaces.s6),
        Semantics(
          header: true,
          child: Text('Espace pro', style: textes.headlineMedium),
        ),
        const SizedBox(height: Espaces.s2),
        Text(
          'Connexion réservée à l\'équipe du salon.',
          style: textes.bodyLarge,
        ),
        const SizedBox(height: Espaces.s6),
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Champ(
                libelle: 'E-mail',
                controleur: _email,
                erreur: _erreurEmail,
                clavier: TextInputType.emailAddress,
                autofill: const [AutofillHints.email, AutofillHints.username],
                actionClavier: TextInputAction.next,
                surValidation: _focusMotDePasse.requestFocus,
              ),
              const SizedBox(height: Espaces.s4),
              Champ(
                libelle: 'Mot de passe',
                controleur: _motDePasse,
                erreur: _erreurMotDePasse,
                motDePasse: true,
                focus: _focusMotDePasse,
                autofill: const [AutofillHints.password],
                actionClavier: TextInputAction.done,
                surValidation: _seConnecter,
              ),
            ],
          ),
        ),
        // Lien de secours (#148) : lien souligné de la charte, sous le champ
        // concerné. Les mots de l'e-mail d'invitation.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _recevoirCode,
            child: const Text('Pas encore de mot de passe, ou oublié ?'),
          ),
        ),
        const SizedBox(height: Espaces.s6),
        if (_erreur != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _erreur!,
              style: textes.bodyLarge!.copyWith(color: Couleurs.erreur),
            ),
          ),
          // Échec : le chemin de secours est proposé là où le regard est
          // (coiffeur invité qui tente un mot de passe, oubli).
          if (_erreur == messageErreurConnexion('invalid_credentials'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _recevoirCode,
                child: const Text('Recevoir un code pour vous connecter'),
              ),
            ),
          const SizedBox(height: Espaces.s3),
        ],
        Bouton(
          pleineLargeur: true,
          libelle: 'Se connecter',
          libelleChargement: 'Connexion…',
          chargement: _enCours,
          surAppui: _seConnecter,
        ),
      ],
    );
  }
}
