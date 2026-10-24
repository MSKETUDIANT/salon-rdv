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
  clients ne pourraient pas réserver.
