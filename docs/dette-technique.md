# Dette technique

Points connus, volontairement laissés pour plus tard.

## Sprint 2 — Réservation (BF-C5)

La policy INSERT de `reservations` (issue #3) ne contrôle que l'identité du
client et la cohérence du salon. Restent à vérifier, côté base ou backend :

- [ ] la réservation tombe dans les horaires du coiffeur ;
- [ ] elle est hors de ses absences ;
- [ ] `fin = debut + duree_minutes` de la prestation ;
- [ ] le coiffeur a la compétence pour la prestation (`competences`).
