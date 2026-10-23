# Dette technique

Points connus, volontairement laissés pour plus tard.

## Sprint 2 — Réservation (BF-C5)

La policy INSERT de `reservations` (issue #3) ne contrôle que l'identité du
client et la cohérence du salon. Restent à vérifier, côté base ou backend :

- [ ] la réservation tombe dans les horaires du coiffeur ;
- [ ] elle est hors de ses absences ;
- [ ] `fin = debut + duree_minutes` de la prestation ;
- [ ] le coiffeur a la compétence pour la prestation (`competences`).

## Dépendances du site (web/)

- [ ] `npm audit` : 5 failles « high » venant de `braces` (déni de service par
  motifs imbriqués, GHSA-vfj7-8cjw-p6xm), tirées par `eslint-config-next`
  via `@next/eslint-plugin-next` → `fast-glob` → `micromatch`. Outil de
  développement seulement (ESLint), absent du site livré. Ne pas faire
  `npm audit fix --force` : il rétrograde `eslint-config-next` en 14.x.
  À revoir quand `eslint-config-next` publiera une version corrigée.
