import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';

// Téléphone du salon (#129, option A de Sparta), depuis la ligne « Téléphone »
// de l'onglet Salon du gérant : affiché sur l'accueil du site (toucher pour
// appeler) et proposé au client quand le délai d'annulation est passé. Champ
// vide : le numéro est retiré. La base vérifie le rôle et le format
// (definir_telephone_salon). Renvoie true si le numéro a changé.
class EcranTelephoneSalon extends StatefulWidget {
  const EcranTelephoneSalon({
    super.key,
    required this.salon,
    required this.telephone,
  });

  final DepotSalon salon;
  // Numéro actuel, null s'il n'y en a pas.
  final String? telephone;

  @override
  State<EcranTelephoneSalon> createState() => _EcranTelephoneSalonState();
}

class _EcranTelephoneSalonState extends State<EcranTelephoneSalon> {
  late final _telephone = TextEditingController(text: widget.telephone ?? '');
  String? _erreurTelephone;
  String? _erreur;
  bool _enCours = false;

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final telephone = _telephone.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (telephone == (widget.telephone ?? '')) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _erreur = null;
      _erreurTelephone = null;
      _enCours = true;
    });
    try {
      await widget.salon.definirTelephone(telephone);
      if (!mounted) return;
      confirmer(
        context,
        telephone.isEmpty ? 'Numéro retiré.' : 'Numéro enregistré.',
      );
      Navigator.of(context).pop(true);
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() {
        _enCours = false;
        // Numéro refusé : sous le champ ; autre erreur : au-dessus du bouton.
        if (erreur.message == messageTelephoneInvalide) {
          _erreurTelephone = erreur.message;
        } else {
          _erreur = erreur.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Téléphone')),
      body: ListeCharte(
        enfants: [
          Champ(
            libelle: 'Téléphone du salon',
            controleur: _telephone,
            erreur: _erreurTelephone,
            aide:
                'Affiché sur le site : les clients le touchent pour appeler. '
                'Laissez vide pour le retirer.',
            clavier: TextInputType.phone,
            autofill: const [AutofillHints.telephoneNumber],
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
    );
  }
}
