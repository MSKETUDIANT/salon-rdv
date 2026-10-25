import 'package:flutter/material.dart';

import '../../data/session.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Connexion de l'équipe : e-mail et mot de passe (comptes créés via #2).
// « Se connecter » n'est jamais désactivé : au clic, ce qui manque est indiqué
// près du champ concerné.
class EcranConnexion extends StatefulWidget {
  const EcranConnexion({super.key, required this.auth});

  final ServiceAuth auth;

  @override
  State<EcranConnexion> createState() => _EcranConnexionState();
}

class _EcranConnexionState extends State<EcranConnexion> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  String? _erreurEmail;
  String? _erreurMotDePasse;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
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
    // En cas de succès, la porte (porte.dart) remplace cet écran.
    setState(() {
      _enCours = false;
      _erreur = erreur;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return PageCharte(
      enfants: [
        Text(
          'Salon RDV',
          style: textes.bodyLarge!.copyWith(color: Couleurs.texteSecondaire),
        ),
        const SizedBox(height: Espaces.s2),
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
                autofill: const [AutofillHints.email],
                actionClavier: TextInputAction.next,
              ),
              const SizedBox(height: Espaces.s4),
              Champ(
                libelle: 'Mot de passe',
                controleur: _motDePasse,
                erreur: _erreurMotDePasse,
                motDePasse: true,
                autofill: const [AutofillHints.password],
                actionClavier: TextInputAction.done,
                surValidation: _seConnecter,
              ),
            ],
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
          const SizedBox(height: Espaces.s3),
        ],
        Bouton(
          libelle: 'Se connecter',
          libelleChargement: 'Connexion…',
          chargement: _enCours,
          surAppui: _seConnecter,
        ),
      ],
    );
  }
}
