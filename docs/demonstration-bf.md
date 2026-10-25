# Démonstration des 15 besoins fonctionnels

Critère d'acceptation du projet (cahier des charges, § 9) : « les 15 besoins
fonctionnels marchent de bout en bout, chacun démontré ». Pour chaque besoin :
où il se trouve, les tests automatisés qui le prouvent, et sa démonstration
**sur la version en ligne**.

- Site client : https://salon-rdv-one.vercel.app
- App pro (Android) : APK de la release `app-pro-v0.1.0`,
  https://github.com/MSKETUDIANT/salon-rdv/releases/tag/app-pro-v0.1.0
- Tests : `npm run verifier:bnf` dans `web/` (README, « Tests »).

## Liste

| Besoin | Où | Prouvé par les tests | Démontré en ligne |
| --- | --- | --- | --- |
| **BF-C1** Voir les créneaux sans compte | site, écran 2 | `creneaux_disponibles.test.sql` (visiteur sans compte) ; `reservation.spec.ts` (aucun champ de connexion avant l'écran 3) | [x] 2026-10-25 : 26 à 29 heures affichées sans compte, aucun champ de connexion |
| **BF-C2** Choisir une prestation | site, écran 1 | `reservation.spec.ts` ; `reservation.test.tsx` | [x] 2026-10-25 : les 4 prestations proposées, avec durée et prix |
| **BF-C3** Choisir un coiffeur qui sait faire la prestation | site, écran 2 | `creneaux_disponibles.test.sql` (compétences, « Peu importe ») ; `reservation.test.tsx` | [x] 2026-10-25 : Couleur → Amira seule ; Coupe homme → Amira et Youssef |
| **BF-C4** Se connecter ou créer un compte au moment de réserver | site, écran 3 | `reservation.spec.ts` (nouveau compte par code à l'écran 3, créneau conservé) ; `ecran-confirmation.test.tsx` ; `auth_roles.test.sql` (compte client créé à l'inscription) | [ ] |
| **BF-C5** Réserver un créneau | site, écran 3 | `reserver.test.sql` ; `reservation.spec.ts` ; `bnf-1-charge.spec.ts` (20 réservations simultanées) | [ ] |
| **BF-C6** Consulter et annuler sa réservation | site, « Mes réservations » | `mes_reservations.test.sql` ; `mes-reservations.spec.ts` ; `ecran-mes-reservations.test.tsx` | [ ] |
| **BF-K1** Voir son planning par jour et par semaine | app pro, espace coiffeur | `planning.test.sql` ; `planning_test.dart` | [ ] sur la base locale (décision de Sparta) |
| **BF-K2** Voir le détail de ses réservations | app pro, fiche d'un rendez-vous | `planning.test.sql` (nom et téléphone, jamais l'e-mail) ; `planning_test.dart` | [ ] |
| **BF-K3** Marquer un rendez-vous terminé (historique) | app pro, fiche d'un rendez-vous | `cloture_encaissement.test.sql` ; `cloture_test.dart` ; `historique_test.dart` | [ ] sur la base locale (décision de Sparta) |
| **BF-K4** Marquer un client absent | app pro, fiche d'un rendez-vous | `cloture_encaissement.test.sql` (absent non encaissable) ; `cloture_test.dart` | [ ] sur la base locale (décision de Sparta) |
| **BF-G1** Gérer horaires et absences des coiffeurs | app pro, espace gérant, « Équipe » | `configuration_salon.test.sql` ; `rls_horaires.test.sql`, `rls_absences.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G2** Gérer le catalogue de prestations | app pro, espace gérant, « Prestations » | `configuration_salon.test.sql` ; `rls_prestations.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G3** Indiquer les compétences de chaque coiffeur | app pro, fiche d'un coiffeur | `configuration_salon.test.sql` ; `rls_competences.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G4** Enregistrer l'encaissement d'un rendez-vous | app pro, fiche d'un rendez-vous, « Historique » | `cloture_encaissement.test.sql` ; `cloture_test.dart` ; `historique_test.dart` | [ ] sur la base locale (décision de Sparta) |
| **BF-G5** Voir le planning de toute l'équipe | app pro, « Planning de l'équipe » | `planning.test.sql` ; `planning_test.dart` | [ ] |

Déjà vérifiés à la main sur la base locale, pendant les issues : BF-G1 à G3
(#9), BF-K1, K2 et G5 (#10), BF-K3, K4 et G4 (#11).

## Démonstration en ligne : déroulé

BF-C1 à C3 ont été démontrés en lecture seule, sans compte. Les autres
demandent un e-mail réel ou un compte de l'équipe sur la base distante : ils
sont à faire par Sparta, dans cet ordre (environ 15 minutes).

**Site, téléphone ou navigateur, en navigation privée :**

1. **BF-C4, BF-C5** : réserver une Coupe homme avec Youssef, se connecter à
   l'écran 3 avec une adresse jamais utilisée sur le site (le code arrive par
   e-mail) → « Réservation confirmée ».
2. **BF-C6** : « Mes réservations » → la réservation est dans « À venir » ;
   l'annuler → elle passe dans « Passées et annulées ».
3. Refaire une réservation (étape 1) avec la même adresse et la garder : elle
   sert aux étapes suivantes.

**App pro, compte gérant de production** (`docs/premier-gerant.md`) :

4. **BF-G2** : « Prestations » → créer une prestation de test, la modifier,
   la désactiver.
5. **BF-G1, BF-G3** : « Équipe » → Youssef → ajouter une plage horaire, une
   absence, cocher une compétence ; puis remettre comme avant.
6. **BF-G5** : « Planning de l'équipe » → la réservation de l'étape 3 apparaît
   dans la colonne de Youssef.
7. **BF-K2** : ouvrir ce rendez-vous → client, téléphone, prestation, heure.

**Espace coiffeur et encaissement (BF-K1, K3, K4, G4) : sur la base locale.**
Décision de Sparta (2026-10-25) : aucune modification en distant. Les
coiffeurs de démonstration n'ont pas de compte de connexion
(`docs/donnees-demo.md`), et un rendez-vous ne se clôture qu'une fois commencé
(les réservations faites aux étapes 1 à 3 sont à venir). Base locale après
`supabase db reset` (le seed contient des rendez-vous d'hier), app pro lancée
selon le README :

8. **BF-K1** : `amira@salon.test` (mot de passe `motdepasse`), « Mon planning »
   → vues Jour et Semaine.
9. **BF-K3, BF-K4** : hier, rendez-vous de 9h → « Terminé » ; avec
   `youssef@salon.test`, hier 16h → « Client absent ».
10. **BF-G4** : `gerant@salon.test`, « Planning de l'équipe », hier → encaisser
    le rendez-vous d'Amira de 10h (terminé) → « Historique » : il apparaît avec
    son montant.

Cocher chaque ligne de la liste après sa démonstration, avec la date.
