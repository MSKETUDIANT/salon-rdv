-- Issue #103 : rendez-vous pour un client de passage (reserver_pour_client),
-- fiche sans compte (option B2), droits gérant / coiffeur (option 2A).
begin;

create extension if not exists pgtap with schema extensions;

select plan(9);

-- Jeu de données : salon à Tunis (UTC+1), lundi 7 janvier 2030.
--   A et B : coiffeurs, 9h-12h, savent faire Coupe (30 min). A absent 11h-12h.
--   C : coiffeur, 9h-12h, ne sait pas faire Coupe.
--   Clients c1 et c2 ; x : compte sans rôle dans ce salon.
--   Ancienne : prestation inactive.
insert into public.salons (id, nom, fuseau_horaire) values
  ('00000000-0000-0000-0000-000000000001', 'Salon test', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@reserver.test',  '{"nom":"Coiffeur A"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'b@reserver.test',  '{"nom":"Coiffeur B"}'),
  ('00000000-0000-0000-0000-0000000000c3', 'c@reserver.test',  '{"nom":"Coiffeur C"}'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@reserver.test', '{"nom":"Client 1"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@reserver.test', '{"nom":"Client 2"}'),
  ('00000000-0000-0000-0000-0000000000f0', 'x@reserver.test',  '{"nom":"Sans rôle"}');

-- Le trigger n'attribue le rôle client que s'il n'existe qu'un salon (le seed
-- en ajoute un) : rôles posés ici.
delete from public.roles_utilisateur
 where utilisateur_id::text like '00000000-0000-0000-0000-0000000000%';
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000d1', 'g@reserver.test', '{"nom":"Gérant"}');
delete from public.roles_utilisateur
 where utilisateur_id = '00000000-0000-0000-0000-0000000000d1';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000001', 'gerant'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'client'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000001', 'client');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes, active) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000001', 'Coupe',    20, 30, true),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000001', 'Ancienne', 10, 30, false);

insert into public.competences (coiffeur_id, prestation_id) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000e1'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e2');

insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 1, '09:00', '12:00'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000b1', 1, '09:00', '12:00'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c3', 1, '09:00', '12:00');

insert into public.absences (salon_id, coiffeur_id, debut, fin) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
   '2030-01-07 11:00+01', '2030-01-07 12:00+01');

-- Se connecter comme un utilisateur donné.
create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- 1. Un visiteur sans compte ne peut pas appeler la fonction.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
  $$ select * from public.reserver_pour_client('Passage', null,
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  '42501', null, 'Visiteur : refusé');
reset role;
set local role authenticated;

-- 2. Un client n'est pas de l'équipe : PT403.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$ select * from public.reserver_pour_client('Passage', null,
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  'PT403', null, 'Client : réservé à l''équipe');

-- 3. Un coiffeur ne réserve pas pour un autre coiffeur.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000a1');
select throws_ok(
  $$ select * from public.reserver_pour_client('Passage', null,
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01',
       '00000000-0000-0000-0000-0000000000b1') $$,
  'PT403', null, 'Coiffeur A pour B : refusé');

-- 4. Le coiffeur réserve pour lui (coiffeur imposé, même sans le préciser).
select results_eq(
  $$ select coiffeur_id from public.reserver_pour_client('Salma Passage', '+21611000111',
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1'::uuid) $$,
  'Coiffeur A : réserve pour lui');

-- 5. Le gérant réserve pour le coiffeur de son choix.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000d1');
select results_eq(
  $$ select coiffeur_id from public.reserver_pour_client('Salma Passage', '+21611000111',
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:30+01',
       '00000000-0000-0000-0000-0000000000b1') $$,
  $$ values ('00000000-0000-0000-0000-0000000000b1'::uuid) $$,
  'Gérant : réserve pour B');

-- 6. Même téléphone : la fiche est retrouvée, pas de doublon.
reset role;
select is(
  (select count(*) from public.utilisateurs where telephone = '+21611000111'),
  1::bigint, 'Même téléphone : une seule fiche, sans compte');
set local role authenticated;
select pg_temp.connecter('00000000-0000-0000-0000-0000000000d1');

-- 7. Créneau déjà pris : PT409 (zéro double réservation).
select throws_ok(
  $$ select * from public.reserver_pour_client('Autre', null,
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', null, 'Créneau pris : PT409');

-- 8. Nom vide : PT400.
select throws_ok(
  $$ select * from public.reserver_pour_client('  ', null,
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:00+01') $$,
  'PT400', null, 'Nom vide : PT400');

-- 9. Supprimer un compte supprime toujours sa fiche (déclencheur, B2).
reset role;
delete from auth.users where id = '00000000-0000-0000-0000-0000000000f0';
select is(
  (select count(*) from public.utilisateurs
    where id = '00000000-0000-0000-0000-0000000000f0'),
  0::bigint, 'Compte supprimé : fiche supprimée');

select * from finish();
rollback;
