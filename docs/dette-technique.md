# Dette technique

Points connus, volontairement laissés pour plus tard.

## Sprint 2 — Réservation (BF-C5) : soldé par #6

La policy INSERT de `reservations` (issue #3) ne contrôlait que l'identité du
client et la cohérence du salon. Depuis #6, elle est supprimée : la fonction
`public.reserver()` est le seul chemin d'insertion et vérifie tout
(tests : `supabase/tests/reserver.test.sql`).

- [x] la réservation tombe dans les horaires du coiffeur ;
- [x] elle est hors de ses absences ;
- [x] `fin = debut + duree_minutes` de la prestation ;
- [x] le coiffeur a la compétence pour la prestation (`competences`).

## Avant la mise en ligne (#13)

- [ ] **Serveur d'envoi SMTP externe obligatoire.** La réservation dépend de
  l'e-mail : le client se connecte à l'écran de confirmation avec un code à
  6 chiffres reçu par e-mail (OTP, charte graphique §5). Le SMTP intégré de
  Supabase n'envoie que quelques e-mails par heure : sans SMTP externe, des
  clients ne pourraient pas réserver. Depuis le 2026-10-25, le SMTP de Gmail
  (mot de passe d'application) le remplace pour les tests et la démo
  (`docs/connexion-code-email.md`) ; reste à passer à un service d'envoi
  transactionnel avec le domaine du salon.

## Annulation (BF-C6, #7) : pas de délai minimum

- [ ] **Délai minimum d'annulation, réglable par le gérant.** Aujourd'hui, un
  client peut annuler jusqu'au début du rendez-vous : le cahier des charges
  ne fixe aucun délai. Depuis #110, la règle est écrite une seule fois, dans
  `private.reservation_annulable()` (migration
  `20261030222241_regle_annulable.sql`), appelée par `annuler_reservation()`
  (refus PT409) et par la colonne `annulable` de `mes_reservations()`. Piste :
  une colonne `salons.delai_annulation_minutes` (défaut 0), modifiable par le
  gérant dans l'app pro (configuration du salon, BF-G1 à G3), lue par cette
  seule fonction, avec un message clair sur le site quand le délai est
  dépassé.

## Encaissement (BF-G4, #11) : corrections sans trace

- [ ] **Une correction de montant efface l'ancien.** Le gérant peut corriger
  le montant d'un encaissement (faute de frappe) : seule la colonne `montant`
  est modifiable, mais l'ancienne valeur n'est conservée nulle part, et on ne
  sait ni qui a corrigé ni quand (`encaisse_par` et `created_at` restent ceux
  de l'encaissement d'origine). Piste : une table `corrections_encaissement`
  (ancien montant, nouveau montant, auteur, date) remplie par un trigger
  `after update of montant`, lisible par le gérant, et affichée dans
  l'historique de l'app pro.

## Absence posée sur un rendez-vous déjà confirmé (#9)

- [ ] **Le client n'est pas prévenu.** Le gérant peut poser une absence qui
  recouvre un rendez-vous confirmé : la base l'accepte, le rendez-vous reste
  confirmé, et seul le gérant est averti dans l'app pro (sans blocage). Le
  client, lui, n'apprend rien et se présentera au salon. Piste : prévenir le
  client par e-mail (avec le SMTP de #13) et lui proposer d'annuler ou de
  choisir un autre créneau, ou demander au gérant de traiter ces rendez-vous
  avant de valider l'absence.
