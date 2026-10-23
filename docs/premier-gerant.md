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

Dans le dashboard Supabase : *SQL Editor*, puis exécuter en remplaçant
l'e-mail, le nom et l'adresse du salon.

```sql
begin;

-- 1. Le salon (s'il n'existe pas encore).
insert into public.salons (nom, adresse)
select 'Nom du salon', 'Adresse du salon'
where not exists (select 1 from public.salons);

-- 2. Rôle gérant pour le compte, dans ce salon.
insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
select u.id, s.id, 'gerant'
  from public.utilisateurs u
 cross join (select id from public.salons limit 1) s
 where u.email = 'mon.email@exemple.com'
on conflict do nothing;

-- 3. Vérification : doit afficher une ligne « gerant ».
select u.email, s.nom, r.role
  from public.roles_utilisateur r
  join public.utilisateurs u on u.id = r.utilisateur_id
  join public.salons s on s.id = r.salon_id
 where u.email = 'mon.email@exemple.com';

commit;
```

Si la vérification n'affiche rien : le compte n'existe pas dans
`public.utilisateurs` (e-mail mal saisi, ou compte créé avant la migration
`auth_utilisateurs_roles`). Faire `rollback;` et corriger avant de recommencer.

Ce SQL ne modifie que des **données**, jamais le schéma. Toute modification du
schéma reste soumise à la règle de CLAUDE.md : migration via la CLI uniquement.

## Ensuite

Le gérant attribue les autres rôles depuis l'application, via
`public.attribuer_role(utilisateur, salon, role)`.
