import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Ajouter un coiffeur (#145, option A de Sparta), depuis l'écran Équipe : le
// gérant saisit le nom et l'e-mail. Si un compte existe déjà avec cette
// adresse, la personne rejoint l'équipe tout de suite ; sinon l'invitation
// attend sa « Première connexion » dans l'app. La base vérifie le rôle, le
// format de l'adresse et « déjà dans l'équipe » (inviter_coiffeur).
// Renvoie le message de confirmation à afficher, null si rien n'a changé.
class EcranInviterCoiffeur extends StatefulWidget {
  const EcranInviterCoiffeur({super.key, required this.salon});
  final DepotSalon salon;

  @override
  State<EcranInviterCoiffeur> createState() => _EcranInviterCoiffeurState();
}

class _EcranInviterCoiffeurState extends State<EcranInviterCoiffeur> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _focusEmail = FocusNode();
  String? _erreurNom;
  String? _erreurEmail;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _focusEmail.dispose();
    super.dispose();
  }

  Future<void> _inviter() async {
    // Espaces superflus retirés : « Nour  Ben » → « Nour Ben ».
    final nom = _nom.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final email = _email.text.trim();
    setState(() {
      _erreur = null;
      _erreurNom = nom.isEmpty ? 'Indiquez le nom du coiffeur.' : null;
      _erreurEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
          ? null
          : 'Indiquez une adresse e-mail valide.';
    });
    if (_erreurNom != null || _erreurEmail != null) return;

    setState(() => _enCours = true);
    try {
      final ajoute = await widget.salon.inviterCoiffeur(nom: nom, email: email);
      if (!mounted) return;
      Navigator.of(context).pop(
        ajoute
            ? "$nom fait maintenant partie de l'équipe."
            : 'Invitation enregistrée pour $nom.',
      );
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        // Adresse refusée par la base : sous le champ ; le reste au-dessus du
        // bouton.
        if (erreur.message.startsWith('Adresse')) {
          _erreurEmail = erreur.message;
        } else if (erreur.message.startsWith('Nom')) {
          _erreurNom = erreur.message;
        } else {
          _erreur = erreur.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un coiffeur')),
      body: AutofillGroup(
        child: ListeCharte(
          enfants: [
            Text(
              // Sans genre : la personne invitée peut être une coiffeuse.
              "Ensuite, dans l'app, « Première connexion » avec cette "
              'adresse : un code est envoyé par e-mail pour créer le mot de '
              'passe.',
              style: textes.bodyLarge,
            ),
            const SizedBox(height: Espaces.s6),
            Champ(
              libelle: 'Nom complet',
              controleur: _nom,
              erreur: _erreurNom,
              aide: "Affiché à l'équipe et aux clients.",
              capitalisation: TextCapitalization.words,
              autofill: const [AutofillHints.name],
              actionClavier: TextInputAction.next,
              surValidation: _focusEmail.requestFocus,
            ),
            const SizedBox(height: Espaces.s4),
            Champ(
              libelle: 'E-mail',
              controleur: _email,
              focus: _focusEmail,
              erreur: _erreurEmail,
              clavier: TextInputType.emailAddress,
              autofill: const [AutofillHints.email],
              actionClavier: TextInputAction.done,
              surValidation: _inviter,
            ),
            const SizedBox(height: Espaces.s6),
            if (_erreur != null) ...[
              MessageErreur(_erreur!),
              const SizedBox(height: Espaces.s3),
            ],
            Bouton(
              libelle: 'Inviter',
              libelleChargement: 'Invitation…',
              chargement: _enCours,
              pleineLargeur: true,
              surAppui: _inviter,
            ),
          ],
        ),
      ),
    );
  }
}
