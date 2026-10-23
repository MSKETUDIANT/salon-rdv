-- Issue #2 : inscription (ligne utilisateurs + rôle client) et attribution
-- des rôles par le gérant du salon.
begin;

create extension if not exists pgtap with schema extensions;

select plan(17);

-- Deux salons : A et B (le seed en ajoute un troisième).
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000000', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000000', 'Salon B');

-- Simule une inscription (ce que fait Supabase Auth).
prepare inscrire(uuid, text, jsonb) as
  insert into auth.users (id, email, raw_user_meta_data) values ($1, $2, $3);

-- ------------------------------------------------------------
-- Inscription
-- ------------------------------------------------------------

execute inscrire('00000000-0000-0000-0000-000000000001', 'alice@test.local',
                 '{"nom":"Alice","salon_id":"0000000a-0000-0000-0000-000000000000"}');

-- 1. La ligne utilisateurs est créée avec le nom et l'e-mail.
select results_eq(
  $$ select nom::text, email::text from public.utilisateurs
      where id = '00000000-0000-0000-0000-000000000001' $$,
  $$ values ('Alice', 'alice@test.local') $$,
  'Inscription : ligne utilisateurs créée (nom, e-mail)'
);

-- 2. Le nouvel inscrit a le rôle client dans le salon demandé, et lui seul.
select results_eq(
  $$ select salon_id, role::text from public.roles_utilisateur
      where utilisateur_id = '00000000-0000-0000-0000-000000000001' $$,
  $$ values ('0000000a-0000-0000-0000-000000000000'::uuid, 'client') $$,
  'Inscription : rôle client dans le salon A, et rien d''autre'
);

-- 3. Un rôle passé dans les métadonnées est ignoré.
execute inscrire('00000000-0000-0000-0000-000000000002', 'malin@test.local',
                 '{"nom":"Malin","role":"gerant","salon_id":"0000000a-0000-0000-0000-000000000000"}');

select results_eq(
  $$ select role::text from public.roles_utilisateur
      where utilisateur_id = '00000000-0000-0000-0000-000000000002' $$,
  $$ values ('client') $$,
  'Métadonnée role=gerant ignorée : seulement client'
);

-- 4. Sans nom dans les métadonnées : partie de l'e-mail avant @.
execute inscrire('00000000-0000-0000-0000-000000000003', 'sans.nom@test.local',
                 '{"salon_id":"0000000a-0000-0000-0000-000000000000"}');

select is(
  (select nom::text from public.utilisateurs where id = '00000000-0000-0000-0000-000000000003'),
  'sans.nom',
  'Nom absent : partie de l''e-mail avant @'
);

-- 5. salon_id invalide : utilisateur créé, sans rôle (inscription non bloquée).
execute inscrire('00000000-0000-0000-0000-000000000004', 'invalide@test.local',
                 '{"nom":"Invalide","salon_id":"pas-un-uuid"}');

select is(
  (select count(*)::int from public.roles_utilisateur
    where utilisateur_id = '00000000-0000-0000-0000-000000000004'),
  0,
  'salon_id invalide : aucun rôle'
);

-- 6. salon_id absent et plusieurs salons : utilisateur créé, sans rôle.
execute inscrire('00000000-0000-0000-0000-000000000005', 'perdu@test.local', '{"nom":"Perdu"}');

select ok(
  exists (select 1 from public.utilisateurs where id = '00000000-0000-0000-0000-000000000005')
  and not exists (select 1 from public.roles_utilisateur
                   where utilisateur_id = '00000000-0000-0000-0000-000000000005'),
  'salon_id absent avec plusieurs salons : utilisateur créé, aucun rôle'
);

-- 7. Une ligne utilisateurs ne peut pas exister sans compte auth.
select throws_ok(
  $$ insert into public.utilisateurs (id, nom)
     values ('00000000-0000-0000-0000-0000000000ff', 'Fantôme') $$,
  '23503',
  null,
  'utilisateurs sans compte auth : refusé (clé étrangère)'
);

-- ------------------------------------------------------------
-- Attribution des rôles
-- ------------------------------------------------------------

-- Gérants : 1 (Alice) pour A, 6 (Bob) pour B. Premier gérant posé hors API.
execute inscrire('00000000-0000-0000-0000-000000000006', 'bob@test.local',
                 '{"nom":"Bob","salon_id":"0000000b-0000-0000-0000-000000000000"}');

insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000000-0000-0000-0000-000000000001', '0000000a-0000-0000-0000-000000000000', 'gerant'),
  ('00000000-0000-0000-0000-000000000006', '0000000b-0000-0000-0000-000000000000', 'gerant');

-- Agit en tant qu'Alice, gérante du salon A.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- 8. La gérante attribue coiffeur à l'utilisateur 3.
select lives_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000003',
                                  '0000000a-0000-0000-0000-000000000000', 'coiffeur') $$,
  'Gérante de A : attribue coiffeur'
);

-- 9. Puis gerant à la même personne.
select lives_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000003',
                                  '0000000a-0000-0000-0000-000000000000', 'gerant') $$,
  'Gérante de A : attribue gerant à la même personne'
);

-- 10. Attribuer deux fois le même rôle : pas d'erreur.
select lives_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000003',
                                  '0000000a-0000-0000-0000-000000000000', 'coiffeur') $$,
  'Même rôle attribué deux fois : pas d''erreur'
);

-- Agit en tant que l'utilisateur 2, simple client du salon A.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated"}', true);

-- 11. Un client ne peut pas attribuer de rôle.
select throws_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000002',
                                  '0000000a-0000-0000-0000-000000000000', 'gerant') $$,
  '42501',
  'Seul un gérant du salon peut attribuer un rôle',
  'Client : attribution refusée (y compris à lui-même)'
);

-- Agit en tant que Bob, gérant du salon B seulement.
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000006","role":"authenticated"}', true);

-- 12. Un gérant d'un autre salon ne peut pas attribuer de rôle dans A.
select throws_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000006',
                                  '0000000a-0000-0000-0000-000000000000', 'gerant') $$,
  '42501',
  'Seul un gérant du salon peut attribuer un rôle',
  'Gérant de B : attribution dans A refusée'
);

-- 13. anon ne peut pas appeler la fonction.
set local role anon;

select throws_ok(
  $$ select public.attribuer_role('00000000-0000-0000-0000-000000000005',
                                  '0000000a-0000-0000-0000-000000000000', 'gerant') $$,
  '42501',
  null,
  'anon : exécution de attribuer_role refusée'
);

reset role;

-- 14. Critère d'acceptation : la même personne est client, coiffeur et gerant
-- dans le salon A, sans doublon.
select results_eq(
  $$ select role::text from public.roles_utilisateur
      where utilisateur_id = '00000000-0000-0000-0000-000000000003'
        and salon_id = '0000000a-0000-0000-0000-000000000000'
      order by role $$,
  $$ values ('client'), ('coiffeur'), ('gerant') $$,
  'Même personne gerant et coiffeur dans le même salon, sans doublon'
);

-- ------------------------------------------------------------
-- Suppression de compte
-- ------------------------------------------------------------

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('000000f1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', 'Coupe', 20, 30);

-- L'utilisateur 2 (client) a aussi une compétence, un horaire et une absence,
-- mais aucune réservation.
insert into public.competences (coiffeur_id, prestation_id) values
  ('00000000-0000-0000-0000-000000000002', '000000f1-0000-0000-0000-000000000000');

insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('0000000a-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002', 1, '09:00', '18:00');

insert into public.absences (salon_id, coiffeur_id, debut, fin) values
  ('0000000a-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002',
   '2026-11-03 09:00+00', '2026-11-03 18:00+00');

-- L'utilisateur 5 a une réservation chez le coiffeur 3.
insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin) values
  ('0000000a-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000003', '000000f1-0000-0000-0000-000000000000',
   '2026-11-02 10:00+00', '2026-11-02 10:30+00');

-- 15. Un compte sans réservation est supprimable.
select lives_ok(
  $$ delete from auth.users where id = '00000000-0000-0000-0000-000000000002' $$,
  'Compte sans réservation (rôle, compétence, horaire, absence) : supprimable'
);

-- 16. La suppression emporte utilisateurs, rôles, compétences, horaires et absences.
select ok(
  not exists (select 1 from public.utilisateurs where id = '00000000-0000-0000-0000-000000000002')
  and not exists (select 1 from public.roles_utilisateur
                   where utilisateur_id = '00000000-0000-0000-0000-000000000002')
  and not exists (select 1 from public.competences
                   where coiffeur_id = '00000000-0000-0000-0000-000000000002')
  and not exists (select 1 from public.horaires
                   where coiffeur_id = '00000000-0000-0000-0000-000000000002')
  and not exists (select 1 from public.absences
                   where coiffeur_id = '00000000-0000-0000-0000-000000000002'),
  'Suppression en cascade : utilisateurs, rôles, compétences, horaires, absences'
);

-- 17. Un compte avec une réservation n'est pas supprimable (historique protégé).
select throws_ok(
  $$ delete from auth.users where id = '00000000-0000-0000-0000-000000000005' $$,
  '23503',
  null,
  'Compte avec réservation : suppression refusée'
);

select * from finish();

rollback;
