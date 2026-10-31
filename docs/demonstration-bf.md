# Démonstration des 15 besoins fonctionnels

Critère d'acceptation du projet (cahier des charges, § 9) : « les 15 besoins
fonctionnels marchent de bout en bout, chacun démontré ». Pour chaque besoin :
où il se trouve, les tests automatisés qui le prouvent, et sa démonstration
**sur la version en ligne**.

- Site client : https://salon-rdv-one.vercel.app
- App pro (Android) : APK de la release `app-pro-v0.4.0`,
  https://github.com/MSKETUDIANT/salon-rdv/releases/tag/app-pro-v0.4.0
- Tests : `npm run verifier:bnf` dans `web/` (README, « Tests »).

## Liste

| Besoin | Où | Prouvé par les tests | Démontré en ligne |
| --- | --- | --- | --- |
| **BF-C1** Voir les créneaux sans compte | site, écran 2 | `creneaux_disponibles.test.sql` (visiteur sans compte) ; `reservation.spec.ts` (aucun champ de connexion avant l'écran 3) | [x] 2026-10-25 : 26 à 29 heures affichées sans compte, aucun champ de connexion |
| **BF-C2** Choisir une prestation | site, écran 1 | `reservation.spec.ts` ; `reservation.test.tsx` | [x] 2026-10-25 : les 4 prestations proposées, avec durée et prix |
| **BF-C3** Choisir un coiffeur qui sait faire la prestation | site, écran 2 | `creneaux_disponibles.test.sql` (compétences, « Peu importe ») ; `reservation.test.tsx` | [x] 2026-10-25 : Couleur → Amira seule ; Coupe homme → Amira et Youssef |
| **BF-C4** Se connecter ou créer un compte au moment de réserver | site, écran 3 | `reservation.spec.ts` (nouveau compte par code à l'écran 3, créneau conservé) ; `ecran-confirmation.test.tsx` ; `auth_roles.test.sql` (compte client créé à l'inscription) | [x] 2026-10-27 (Sparta) : code reçu par e-mail à l'écran 3, adresse neuve, « Réservation confirmée » |
| **BF-C5** Réserver un créneau | site, écran 3 | `reserver.test.sql` ; `reservation.spec.ts` ; `bnf-1-charge.spec.ts` (20 réservations simultanées) | [x] 2026-10-27 (Sparta) : Coupe homme avec Youssef réservée |
| **BF-C6** Consulter et annuler sa réservation | site, « Mes réservations » | `mes_reservations.test.sql` ; `mes-reservations.spec.ts` ; `ecran-mes-reservations.test.tsx` | [x] 2026-10-27 (Sparta) : réservation dans « À venir », annulée, passée dans « Passées et annulées » |
| **BF-K1** Voir son planning par jour et par semaine | app pro, espace coiffeur | `planning.test.sql` ; `planning_test.dart` | [x] 2026-10-27 (Sparta), sur la base locale (décision de Sparta) : vues Jour et Semaine |
| **BF-K2** Voir le détail de ses réservations | app pro, fiche d'un rendez-vous | `planning.test.sql` (nom et téléphone, jamais l'e-mail) ; `planning_test.dart` | [ ] |
| **BF-K3** Marquer un rendez-vous terminé (historique) | app pro, fiche d'un rendez-vous | `cloture_encaissement.test.sql` ; `cloture_test.dart` ; `historique_test.dart` | [x] 2026-10-27 (Sparta), sur la base locale (décision de Sparta) : rendez-vous d'hier 9h marqué « Terminé » |
| **BF-K4** Marquer un client absent | app pro, fiche d'un rendez-vous | `cloture_encaissement.test.sql` (absent non encaissable) ; `cloture_test.dart` | [x] 2026-10-27 (Sparta), sur la base locale (décision de Sparta) : rendez-vous d'hier 16h de Youssef marqué « Client absent » |
| **BF-G1** Gérer horaires et absences des coiffeurs | app pro, espace gérant, onglet Salon → « Équipe » | `configuration_salon.test.sql` ; `rls_horaires.test.sql`, `rls_absences.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G2** Gérer le catalogue de prestations | app pro, espace gérant, onglet Salon → « Prestations » | `configuration_salon.test.sql` ; `rls_prestations.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G3** Indiquer les compétences de chaque coiffeur | app pro, fiche d'un coiffeur | `configuration_salon.test.sql` ; `rls_competences.test.sql` ; `gerant_test.dart` | [ ] |
| **BF-G4** Enregistrer l'encaissement d'un rendez-vous | app pro, fiche d'un rendez-vous, « Historique » | `cloture_encaissement.test.sql` ; `cloture_test.dart` ; `historique_test.dart` | [x] 2026-10-27 (Sparta), sur la base locale (décision de Sparta) : rendez-vous d'Amira de 10h encaissé, présent dans « Historique » avec son montant |
| **BF-G5** Voir le planning de toute l'équipe | app pro, espace gérant, onglet Planning | `planning.test.sql` ; `planning_test.dart` | [ ] |

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

4. **BF-G2** : onglet Salon → « Prestations » → créer une prestation de test,
   la modifier, la désactiver.
5. **BF-G1, BF-G3** : onglet Salon → « Équipe » → Youssef → ajouter une plage
   horaire, une absence, cocher une compétence ; puis remettre comme avant.
6. **BF-G5** : onglet Planning → pastille « Youssef », jour de la réservation
   (bande des jours) → la réservation de l'étape 3 apparaît.
7. **BF-K2** : toucher ce rendez-vous → fiche : client, téléphone, prestation,
   heure.

**Espace coiffeur et encaissement (BF-K1, K3, K4, G4) : sur la base locale.**
Décision de Sparta (2026-10-25) : aucune modification en distant. Les
coiffeurs de démonstration n'ont pas de compte de connexion
(`docs/donnees-demo.md`), et un rendez-vous ne se clôture qu'une fois commencé
(les réservations faites aux étapes 1 à 3 sont à venir). Base locale après
`supabase db reset` (le seed contient des rendez-vous d'hier), app pro lancée
selon le README :

8. **BF-K1** : `amira@salon.test` (mot de passe `motdepasse`), onglet Planning
   → bande des jours de la semaine, vue horaire du jour, puis vue liste.
9. **BF-K3, BF-K4** : hier, rendez-vous de 9h → « Terminé » ; avec
   `youssef@salon.test`, hier 16h → « Client absent ».
10. **BF-G4** : `gerant@salon.test`, onglet Planning, hier → encaisser
    le rendez-vous d'Amira de 10h (terminé) → « Historique » : il apparaît avec
    son montant.

Cocher chaque ligne de la liste après sa démonstration, avec la date.

**Démonstration du 2026-10-27 (Sparta)** : étapes 1 à 3 faites en ligne ;
étapes 8 à 10 faites sur la base locale, comme prévu. Les étapes 4 à 7
(BF-G1, G2, G3, G5, K2) ont été faites avec l'app pro branchée sur la base
**locale** au lieu de la production : rien n'apparaît en production
(statistiques des tables : 4 prestations du script de démo, aucune ligne
modifiée ni supprimée dans `prestations`, `horaires`, `absences`,
`competences`). Elles restent à refaire en production, avec l'APK
`app-pro-v0.4.0` (ou une version antérieure) et le compte gérant de production.
