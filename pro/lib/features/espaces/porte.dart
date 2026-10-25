import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/roles.dart';
import '../../data/session.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import '../connexion/ecran_connexion.dart';
import 'ecran_espace.dart';

// Aiguillage selon la session et les rôles dans le salon :
//   pas connecté → connexion ;
//   aucun rôle pro (client seul, ou rien) → accès refusé ;
//   un seul espace → cet espace ; gérant et coiffeur → choix, puis bascule.
class Porte extends StatefulWidget {
  const Porte({super.key, required this.auth, required this.roles});

  final ServiceAuth auth;
  final DepotRoles roles;

  @override
  State<Porte> createState() => _PorteState();
}

class _PorteState extends State<Porte> {
  late String? _compte = widget.auth.compte;
  late final StreamSubscription<String?> _abonnement;

  // null : lecture en cours ; erreur : lecture impossible.
  List<Espace>? _espaces;
  bool _erreur = false;
  Espace? _espace;

  @override
  void initState() {
    super.initState();
    _abonnement = widget.auth.changements.listen((compte) {
      if (compte == _compte) return;
      setState(() {
        _compte = compte;
        _espaces = null;
        _espace = null;
      });
      if (compte != null) _lireRoles();
    });
    if (_compte != null) _lireRoles();
  }

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }

  Future<void> _lireRoles() async {
    setState(() => _erreur = false);
    try {
      final espaces = espacesPro(await widget.roles.rolesDansLeSalon());
      if (!mounted) return;
      setState(() {
        _espaces = espaces;
        _espace = espaces.length == 1 ? espaces.single : null;
      });
    } catch (_) {
      if (mounted) setState(() => _erreur = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    final espaces = _espaces;

    if (_compte == null) return EcranConnexion(auth: widget.auth);

    if (_erreur) {
      return PageCharte(
        enfants: [
          Text(
            'Impossible de lire vos accès.',
            style: textes.bodyLarge!.copyWith(color: Couleurs.erreur),
          ),
          const SizedBox(height: Espaces.s4),
          Bouton(libelle: 'Réessayer', secondaire: true, surAppui: _lireRoles),
          const SizedBox(height: Espaces.s2),
          TextButton(
            onPressed: widget.auth.seDeconnecter,
            child: const Text('Se déconnecter'),
          ),
        ],
      );
    }

    if (espaces == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (espaces.isEmpty) {
      return PageCharte(
        enfants: [
          Semantics(
            header: true,
            child: Text(
              'Accès réservé à l\'équipe',
              style: textes.headlineMedium,
            ),
          ),
          const SizedBox(height: Espaces.s4),
          Text(
            'Le compte $_compte n\'a pas de rôle de coiffeur ou de gérant dans ce salon. '
            'Pour réserver un rendez-vous, utilisez le site du salon.',
            style: textes.bodyLarge,
          ),
          const SizedBox(height: Espaces.s6),
          Bouton(
            libelle: 'Se déconnecter',
            surAppui: widget.auth.seDeconnecter,
          ),
        ],
      );
    }

    // Deux choix de même poids : boutons secondaires (un seul bouton
    // principal par écran, charte §4).
    final espace = _espace;
    if (espace == null) {
      return PageCharte(
        enfants: [
          Semantics(
            header: true,
            child: Text('Choisir un espace', style: textes.headlineMedium),
          ),
          const SizedBox(height: Espaces.s2),
          Text(
            'Vous êtes gérant et coiffeur dans ce salon.',
            style: textes.bodyLarge,
          ),
          const SizedBox(height: Espaces.s6),
          for (final choix in espaces) ...[
            Bouton(
              secondaire: true,
              libelle: choix.titre,
              surAppui: () => setState(() => _espace = choix),
            ),
            const SizedBox(height: Espaces.s3),
          ],
          const SizedBox(height: Espaces.s2),
          TextButton(
            onPressed: widget.auth.seDeconnecter,
            child: const Text('Se déconnecter'),
          ),
        ],
      );
    }

    final autres = espaces.where((e) => e != espace).toList();
    return EcranEspace(
      espace: espace,
      compte: _compte!,
      autreEspace: autres.isEmpty ? null : autres.first,
      surBascule: (cible) => setState(() => _espace = cible),
      surDeconnexion: widget.auth.seDeconnecter,
    );
  }
}
