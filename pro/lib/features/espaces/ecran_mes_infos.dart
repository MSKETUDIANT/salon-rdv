import 'package:flutter/material.dart';

import '../../data/planning.dart';
import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Mes infos (#106, option A de Sparta) : le nom seul, depuis la ligne
// « Modifier mes infos » du profil. Le nom s'affiche dans l'app (profil,
// « Bonjour », planning du gérant) et sur le site client (choix du coiffeur).
// L'e-mail, identifiant de connexion, est affiché sans être modifiable.
// Renvoie true si le nom est enregistré.
class EcranMesInfos extends StatefulWidget {
  const EcranMesInfos({
    super.key,
    required this.planning,
    required this.compte,
    required this.nom,
  });

  final DepotPlanning planning;
  // E-mail du compte connecté.
  final String compte;
  // Nom actuel, null s'il n'a pas pu être lu.
  final String? nom;

  @override
  State<EcranMesInfos> createState() => _EcranMesInfosState();
}

class _EcranMesInfosState extends State<EcranMesInfos> {
  late final _nom = TextEditingController(text: widget.nom ?? '');
  String? _erreurNom;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    // Espaces superflus retirés : « Amira  Ben Salah » → « Amira Ben Salah ».
    final nom = _nom.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    setState(() {
      _erreur = null;
      _erreurNom = nom.isEmpty ? 'Indiquez votre nom.' : null;
    });
    if (nom.isEmpty) return;
    if (nom == widget.nom) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _enCours = true);
    try {
      await widget.planning.modifierMonNom(nom);
      if (mounted) Navigator.of(context).pop(true);
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        _erreur = erreur.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes infos')),
      body: ListeCharte(
        enfants: [
          Champ(
            libelle: 'Nom complet',
            controleur: _nom,
            erreur: _erreurNom,
            aide: 'Affiché à l\'équipe et aux clients.',
            capitalisation: TextCapitalization.words,
            autofill: const [AutofillHints.name],
            actionClavier: TextInputAction.done,
            surValidation: _enregistrer,
          ),
          const SizedBox(height: Espaces.s6),
          // E-mail en lecture seule : libellé et valeur, sans champ.
          Semantics(
            container: true,
            label: 'E-mail, ${widget.compte}, non modifiable',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('E-mail', style: textes.labelLarge),
                const SizedBox(height: Espaces.s1),
                Text(widget.compte, style: textes.bodyLarge),
                Text(
                  'Identifiant de connexion, non modifiable ici.',
                  style: textes.bodySmall,
                ),
              ],
            ),
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
    );
  }
}
