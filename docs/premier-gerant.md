# Créer le premier gérant (base distante)

Seul un gérant peut attribuer les rôles (`public.attribuer_role`). Le tout
premier gérant d'un salon est donc créé **une seule fois, à la main**, par le
propriétaire du projet Supabase.

Pourquoi pas une fonction d'amorçage automatique : le premier compte inscrit
pourrait se proclamer gérant. C'est une faille, d'où ce SQL manuel ponctuel.

> En local, rien à faire : `supabase/seed.sql` crée le salon de démo et le
> gérant `gerant@salon.test` à chaque `supabase db reset`.

## Prérequis

- Les migrations sont appliquées en distant (`supabase migration list` : mêmes
  versions dans les colonnes Local et Remote).
- Le compte du futur gérant existe : inscription via le site (ou *Authentication
  → Users → Add user* dans le dashboard).
- En distant, **la confirmation d'e-mail est active** : le compte doit avoir
  confirmé son e-mail avant de pouvoir se connecter. À défaut, le confirmer
  depuis le dashboard (*Authentication → Users → … → Confirm email*).

## Procédure

Dans le dashboard Supabase : *SQL Editor*. Deux étapes, dans cet ordre.

### Étape 1 — Créer le salon

À faire **une seule fois**, avant les premières inscriptions : tant qu'il
n'existe qu'un salon, le trigger d'inscription donne automatiquement le rôle
client dans ce salon. Un compte inscrit avant la création du salon n'a aucun rôle.

Vérifier d'abord qu'aucun salon n'existe (0 ligne attendue) :

```sql
select id, nom from public.salons;
```

Puis créer le salon, en remplaçant le nom et l'adresse (l'adresse est
facultative : `null` accepté) :

```sql
insert into public.salons (nom, adresse)
values ('Nom du salon', 'Adresse du salon')
returning id;
```

**Noter l'`id` renvoyé** : il sert à l'étape 2 et c'est la valeur de
`NEXT_PUBLIC_SALON_ID` pour le site (Vercel, Production et Preview).

### Étape 2 — Donner le rôle gérant

Exécuter en remplaçant l'`id` du salon (étape 1) et l'e-mail du compte :

```sql
begin;

-- 1. Rôle gérant pour le compte, dans ce salon.
insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
select u.id, '00000000-0000-0000-0000-000000000000', 'gerant'
  from public.utilisateurs u
 where u.email = 'mon.email@exemple.com'
on conflict do nothing;

-- 2. Vérification : doit afficher une ligne « gerant ».
select u.email, s.nom, r.role
  from public.roles_utilisateur r
  join public.utilisateurs u on u.id = r.utilisateur_id
  join public.salons s on s.id = r.salon_id
 where u.email = 'mon.email@exemple.com';

commit;
```

Si la vérification n'affiche rien : le compte n'existe pas dans
`public.utilisateurs` (e-mail mal saisi, ou compte créé avant la migration
`auth_utilisateurs_roles`), ou l'`id` du salon est faux. Faire `rollback;` et
corriger avant de recommencer.

Ce SQL ne modifie que des **données**, jamais le schéma. Toute modification du
schéma reste soumise à la règle de CLAUDE.md : migration via la CLI uniquement.

## Ensuite

Le gérant ajoute ensuite ses coiffeurs depuis l'app pro (#145, #148) : Salon →
Équipe → « Ajouter un coiffeur » (nom et e-mail). Si un compte confirmé existe
déjà avec cette adresse, il devient coiffeur tout de suite ; sinon, un e-mail
d'invitation part (lien de l'app et marche à suivre). La personne touche
« Pas encore de mot de passe, ou oublié ? » dans l'app, reçoit un code et
choisit son mot de passe, et la base lui donne le rôle coiffeur.

Un compte gérant créé sur le site (connexion par code) n'a pas de mot de
passe : il le crée de la même façon, avec « Pas encore de mot de passe, ou
oublié ? » dans l'app pro (`docs/connexion-code-email.md`).
