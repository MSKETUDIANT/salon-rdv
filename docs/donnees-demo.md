# Données de démonstration (base distante)

Le site déployé n'affiche des créneaux que si le salon a des coiffeurs, des
prestations, des compétences et des horaires. Tant que le gérant ne peut pas
les saisir (app pro, #9), le script `supabase/demo/donnees-demo.sql` ajoute
des **données fictives**, reprises du seed local, pour montrer le parcours de
réservation.

C'est, avec la procédure du premier gérant (`docs/premier-gerant.md`), le seul
SQL manuel autorisé en distant (CLAUDE.md, section 5). Il ne touche que des
**données**, jamais le schéma.

> En local, rien à faire : `supabase/seed.sql` crée des données équivalentes à
> chaque `supabase db reset`.

## Ce que le script ajoute

| Données | Contenu |
|---|---|
| Coiffeurs | Amira (toutes les prestations ; mardi-samedi, 9h-13h et 14h-19h) et Youssef (coupes ; lundi-samedi, 10h-18h) |
| Prestations | Coupe femme (35 DT, 45 min), Coupe homme (20 DT, 30 min), Brushing (25 DT, 30 min), Couleur (80 DT, 1 h 30) |
| Compétences | 4 pour Amira, 2 pour Youssef |
| Horaires | 10 plages pour Amira, 6 pour Youssef |

Pas d'absence ni de réservation : une réservation exige un vrai client.

Les données de démo sont repérables :

- tous leurs ids commencent par `de300000-0000-4000-8000-` ;
- les comptes des coiffeurs sont en `@demo.salon-rdv.invalid`, avec
  `"demo": true` dans leurs métadonnées.

Ces comptes n'ont **ni mot de passe ni identité de connexion** : personne ne
peut s'y connecter, et aucun e-mail ne peut arriver sur un domaine `.invalid`.

## Prérequis

- Les migrations sont appliquées en distant (`supabase migration list` : mêmes
  versions dans les colonnes Local et Remote).
- Le salon existe (`docs/premier-gerant.md`, étape 1) et c'est **le seul** : le
  script s'arrête sans rien écrire s'il trouve zéro ou plusieurs salons.
- Accord de Sparta pour cette exécution.

## Procédure

Depuis la racine du dépôt, sur `main` à jour, projet Supabase lié
(`supabase link`).

### Étape 1 — Exécuter le script

```bash
supabase db query --linked -f supabase/demo/donnees-demo.sql
```

Réponse attendue : `DO`. À défaut de CLI, coller le contenu du fichier dans le
dashboard Supabase (*SQL Editor*) et l'exécuter.

Le script est **une seule instruction, atomique** : soit tout est enregistré,
soit rien. Il se contrôle lui-même à la fin (2 coiffeurs, 4 prestations,
6 compétences, 16 horaires de démo) et annule tout si le compte n'y est pas.
Messages d'erreur possibles :

- `il faut exactement un salon, trouvé N` : créer le salon d'abord, ou ne pas
  utiliser ce script sur une base à plusieurs salons ;
- `Données de démo incomplètes (…)` : rien n'est enregistré ; signaler le
  message avant toute nouvelle tentative.

### Étape 2 — Vérifier

```bash
supabase db query --linked -f supabase/demo/verifier-demo.sql -o table
```

Attendu : deux lignes, Amira et Youssef, rôles `client, coiffeur`, 4 et 2
compétences, 10 et 6 horaires, 4 prestations de démo. (Lecture seule.)

Puis sur le site déployé : `/reserver` liste les 4 prestations ; l'écran des
créneaux propose Amira et Youssef.

Les pages du site sont en cache une minute au plus : attendre une minute si
`/reserver` affiche encore « Aucune prestation ».

## Rejouer

Le script est idempotent : le relancer ne crée aucun doublon (ids fixes,
`on conflict do nothing`). Il ne recrée pas non plus une ligne de démo
modifiée entre-temps : il ne fait qu'ajouter ce qui manque.

## Retirer les données de démo

Pas encore de script : le retrait sera décidé avec Sparta avant la mise en
service réelle du salon (README et mise en ligne, #13). Une réservation faite
sur un coiffeur ou une prestation de démo empêchera leur suppression : elle
protège l'historique.
