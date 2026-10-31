import 'package:flutter/material.dart';

import '../../data/salon.dart';
import '../../ui/chargement.dart';
import '../../ui/charte.dart';
import '../../ui/composants.dart';
import 'ecran_coiffeur.dart';
import 'ecran_inviter_coiffeur.dart';

// Coiffeurs du salon : chacun ouvre sa fiche horaires, absences et
// compétences. Le gérant ajoute un coiffeur par invitation (#145) ; les
// invitations en attente suivent la liste, avec un menu « Renvoyer » et
// « Annuler » (#148).
class EcranEquipe extends StatefulWidget {
  const EcranEquipe({super.key, required this.salon});
  final DepotSalon salon;

  @override
  State<EcranEquipe> createState() => _EcranEquipeState();
}

class _EcranEquipeState extends State<EcranEquipe> {
  int _version = 0;
  // Invitation en cours de renvoi ou d'annulation.
  String? _enCours;

  Future<(List<Coiffeur>, List<Invitation>)> _lire() async {
    final resultats = await Future.wait<dynamic>([
      widget.salon.coiffeurs(),
      widget.salon.invitations(),
    ]);
    return (resultats[0] as List<Coiffeur>, resultats[1] as List<Invitation>);
  }

  Future<void> _ajouter() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EcranInviterCoiffeur(salon: widget.salon),
      ),
    );
    if (!mounted || message == null) return;
    setState(() => _version++);
    confirmer(context, message);
  }

  // Renvoyer (#148) : même invitation, nouvel e-mail.
  Future<void> _renvoyer(Invitation invitation) => _agir(invitation, () async {
    final resultat = await widget.salon.inviterCoiffeur(
      nom: invitation.nom,
      email: invitation.email,
    );
    return messageInvitation(resultat, invitation.nom);
  });

  // Annuler se refait d'une nouvelle invitation : pas de confirmation.
  Future<void> _annuler(Invitation invitation) => _agir(invitation, () async {
    await widget.salon.annulerInvitation(invitation.id);
    return 'Invitation de ${invitation.nom} annulée.';
  });

  Future<void> _agir(
    Invitation invitation,
    Future<String> Function() action,
  ) async {
    setState(() => _enCours = invitation.id);
    try {
      final message = await action();
      if (!mounted) return;
      setState(() {
        _enCours = null;
        _version++;
      });
      confirmer(context, message);
    } on ErreurSalon catch (erreur) {
      if (!mounted) return;
      setState(() => _enCours = null);
      confirmer(context, erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe')),
      body: ListeCharte(
        enfants: [
          Align(
            alignment: Alignment.centerLeft,
            child: Bouton(libelle: 'Ajouter un coiffeur', surAppui: _ajouter),
          ),
          const SizedBox(height: Espaces.s6),
          Chargement<(List<Coiffeur>, List<Invitation>)>(
            key: ValueKey(_version),
            lire: _lire,
            afficher: (context, donnees, _) {
              final (coiffeurs, invitations) = donnees;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (coiffeurs.isEmpty)
                    Text(
                      "Aucun coiffeur pour l'instant. Invitez votre "
                      'équipe avec « Ajouter un coiffeur ».',
                      style: textes.bodyLarge,
                    ),
                  for (final c in coiffeurs)
                    _LigneCoiffeur(
                      nom: c.nom,
                      surAppui: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              EcranCoiffeur(salon: widget.salon, coiffeur: c),
                        ),
                      ),
                    ),
                  if (invitations.isNotEmpty) ...[
                    const SizedBox(height: Espaces.s6),
                    Semantics(
                      header: true,
                      child: Text(
                        'Invitations en attente',
                        style: textes.labelSmall,
                      ),
                    ),
                    const SizedBox(height: Espaces.s2),
                    for (final i in invitations)
                      _LigneInvitation(
                        invitation: i,
                        enCours: _enCours == i.id,
                        actif: _enCours == null,
                        surRenvoyer: () => _renvoyer(i),
                        surAnnuler: () => _annuler(i),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Ligne d'un coiffeur (#92, même logique que le lot 2) : avatar rond, nom,
// chevron ; filet fin, sans carte. Ce que la fiche contient (identique pour
// tous) est lu par TalkBack, pas répété à l'écran.
class _LigneCoiffeur extends StatelessWidget {
  const _LigneCoiffeur({required this.nom, required this.surAppui});
  final String nom;
  final VoidCallback surAppui;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '$nom, horaires, absences et compétences',
      onTap: surAppui,
      excludeSemantics: true,
      child: InkWell(
        onTap: surAppui,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: Espaces.s2),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Couleurs.separateur)),
          ),
          child: Row(
            children: [
              Avatar(nom: nom, taille: 40),
              const SizedBox(width: Espaces.s3),
              Expanded(child: Text(nom, style: textes.titleSmall)),
              const Icon(Icons.chevron_right, color: Couleurs.texteSecondaire),
            ],
          ),
        ),
      ),
    );
  }
}

// Invitation en attente (#145) : même ligne que les coiffeurs, icône
// d'enveloppe à la place de l'avatar, nom et adresse ; à droite, menu
// « Renvoyer l'invitation » / « Annuler l'invitation » (#148 : deux boutons
// ne tiennent pas à côté de l'adresse à 360 px).
class _LigneInvitation extends StatelessWidget {
  const _LigneInvitation({
    required this.invitation,
    required this.enCours,
    required this.actif,
    required this.surRenvoyer,
    required this.surAnnuler,
  });
  final Invitation invitation;
  final bool enCours;
  final bool actif;
  final VoidCallback surRenvoyer;
  final VoidCallback surAnnuler;

  @override
  Widget build(BuildContext context) {
    final textes = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: Espaces.s2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Couleurs.separateur)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 40,
            child: ExcludeSemantics(
              child: Icon(Icons.mail_outline, color: Couleurs.texteSecondaire),
            ),
          ),
          const SizedBox(width: Espaces.s3),
          Expanded(
            child: Semantics(
              container: true,
              label:
                  '${invitation.nom}, invitation en attente, '
                  '${invitation.email}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invitation.nom, style: textes.titleSmall),
                  Text(invitation.email, style: textes.bodySmall),
                ],
              ),
            ),
          ),
          if (enCours)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<VoidCallback>(
              enabled: actif,
              tooltip: "Actions sur l'invitation de ${invitation.nom}",
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: surRenvoyer,
                  child: const Text("Renvoyer l'invitation"),
                ),
                PopupMenuItem(
                  value: surAnnuler,
                  child: const Text("Annuler l'invitation"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
