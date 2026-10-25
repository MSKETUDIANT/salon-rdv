-- Issue #10 : plannings (BF-K1, BF-K2, BF-G5). Un coiffeur ne lit que ses
-- rendez-vous, le gérant ceux de son salon ; des clients, le coiffeur ne voit
-- que le nom et le téléphone.
begin;

create extension if not exists pgtap with schema extensions;

select plan(32);

-- Jeu de données : salons A (Tunis, UTC+1) et B.
--   gA : gérant de A ; c1, c2 : coiffeurs de A ; cl : client de A (avec
--   téléphone) ; cB : coiffeur de B ; gB : gérant de B.
-- Rendez-vous (semaine du lundi 7 janvier 2030) :
--   r1 c1/cl lundi 9h ; r2 c2/cl lundi 10h ; r3 c1 lundi 11h annulé ;
--   r4 c1 dimanche 20 janvier ; r5 c1 20 février (au-delà de 31 jours) ;
--   r6 c1 lundi 0h30 heure de Tunis (dimanche 23h30 UTC) ; rB dans le salon B.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000010', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000010', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, phone, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000010', 'ga@planning.test', null,           '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000010', 'c1@planning.test', null,           '{"nom":"Coiffeur 1"}'),
  ('00000c02-0000-0000-0000-000000000010', 'c2@planning.test', null,           '{"nom":"Coiffeur 2"}'),
  ('00000c1a-0000-0000-0000-000000000010', 'cl@planning.test', '21620000000',  '{"nom":"Salma"}'),
  ('00000cb1-0000-0000-0000-000000000010', 'cb@planning.test', null,           '{"nom":"Coiffeur B"}'),
  ('00000b01-0000-0000-0000-000000000010', 'gb@planning.test', null,           '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000010';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', 'gerant'),
  ('00000c01-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', 'coiffeur'),
  ('00000c02-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', 'coiffeur'),
  ('00000c1a-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', 'client'),
  ('00000cb1-0000-0000-0000-000000000010', '0000000b-0000-0000-0000-000000000010', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000010', '0000000b-0000-0000-0000-000000000010', 'gerant');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('0000f0a1-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', 'Coupe', 20, 30),
  ('0000f0b1-0000-0000-0000-000000000010', '0000000b-0000-0000-0000-000000000010', 'Coupe B', 25, 30);

insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('00000001-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c01-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-01-07 09:00+01', '2030-01-07 09:30+01', 'confirmee'),
  ('00000002-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c02-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-01-07 10:00+01', '2030-01-07 10:30+01', 'confirmee'),
  ('00000003-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c01-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-01-07 11:00+01', '2030-01-07 11:30+01', 'annulee'),
  ('00000004-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c01-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-01-20 09:00+01', '2030-01-20 09:30+01', 'confirmee'),
  ('00000005-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c01-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-02-20 09:00+01', '2030-02-20 09:30+01', 'confirmee'),
  ('00000006-0000-0000-0000-000000000010', '0000000a-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000c01-0000-0000-0000-000000000010', '0000f0a1-0000-0000-0000-000000000010', '2030-01-07 00:30+01', '2030-01-07 01:00+01', 'confirmee'),
  ('0000000b-0000-0000-0000-000000000010', '0000000b-0000-0000-0000-000000000010', '00000c1a-0000-0000-0000-000000000010',
   '00000cb1-0000-0000-0000-000000000010', '0000f0b1-0000-0000-0000-000000000010', '2030-01-07 09:00+01', '2030-01-07 09:30+01', 'confirmee');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ------------------------------------------------------------
-- Structure
-- ------------------------------------------------------------

select is(
  (select count(*)::int from pg_policies
    where tablename = 'utilisateurs' and policyname = 'utilisateurs : coiffeur lit ses clients'),
  0, 'Le coiffeur ne lit plus la table utilisateurs de ses clients (policy supprimée)');

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
     from pg_proc p where p.oid = 'public.planning(uuid, date, date, uuid)'::regprocedure),
  'planning : security definer, search_path fixé');

select ok(
  not has_function_privilege('anon', 'public.planning(uuid, date, date, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.planning(uuid, date, date, uuid)', 'execute')
  and not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
     where p.oid = 'public.planning(uuid, date, date, uuid)'::regprocedure and a.grantee = 0),
  'planning : exécutable par authenticated seulement (ni public ni anon)');

select ok(
  pg_get_function_result('public.planning(uuid, date, date, uuid)'::regprocedure) !~* 'email|client_id',
  'planning : ne renvoie ni e-mail ni identifiant du client');

-- ------------------------------------------------------------
-- Sans compte
-- ------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  '42501', null, 'Sans compte : planning refusé');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  'PT401', 'Connexion requise', 'Sans identifiant : PT401');

-- ------------------------------------------------------------
-- Coiffeur : son planning seulement (BF-K1, BF-K2)
-- ------------------------------------------------------------

select pg_temp.connecter('00000c01-0000-0000-0000-000000000010');

select results_eq(
  $$ select id from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  $$ values ('00000006-0000-0000-0000-000000000010'::uuid), ('00000001-0000-0000-0000-000000000010'::uuid) $$,
  'Coiffeur 1, semaine du 7 : ses rendez-vous seulement (0h30 et 9h), ni le collègue, ni l''annulé, ni le 20');

select results_eq(
  $$ select statut::text, prestation, duree_minutes, client_nom, client_telephone, debut, fin
       from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-07')
      where id = '00000001-0000-0000-0000-000000000010' $$,
  $$ values ('confirmee', 'Coupe'::varchar, 30, 'Salma'::varchar, '21620000000'::varchar,
             '2030-01-07 09:00+01'::timestamptz, '2030-01-07 09:30+01'::timestamptz) $$,
  'Détail (BF-K2) : statut, prestation, durée, nom et téléphone du client, horaires');

select results_eq(
  $$ select id from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-07') $$,
  $$ values ('00000006-0000-0000-0000-000000000010'::uuid), ('00000001-0000-0000-0000-000000000010'::uuid) $$,
  'Jour du salon : 0h30 heure de Tunis (dimanche 23h30 UTC) compte pour le lundi');

select results_eq(
  $$ select id from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13',
                                    '00000c01-0000-0000-0000-000000000010') $$,
  $$ values ('00000006-0000-0000-0000-000000000010'::uuid), ('00000001-0000-0000-0000-000000000010'::uuid) $$,
  'Coiffeur 1 qui se désigne lui-même : accepté');

select results_eq(
  $$ select count(*)::int from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-02-06') $$,
  $$ values (3) $$,
  'Période de 31 jours : acceptée, le 20 janvier oui, le 20 février non');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-02-07') $$,
  'PT400', 'Période de 1 à 31 jours', 'Période de 32 jours : refusée (PT400)');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-13', '2030-01-07') $$,
  'PT400', 'Période de 1 à 31 jours', 'Période à l''envers : refusée (PT400)');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', null, '2030-01-13') $$,
  'PT400', 'Période de 1 à 31 jours', 'Date de début absente : refusée (PT400)');

-- Refus : le planning d'un collègue.
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13',
                                   '00000c02-0000-0000-0000-000000000010') $$,
  'PT403', 'Un coiffeur ne voit que son planning', 'Coiffeur 1 : planning du coiffeur 2 refusé (PT403)');
select is(
  (select count(*)::int from public.reservations where coiffeur_id = '00000c02-0000-0000-0000-000000000010'),
  0, 'Coiffeur 1 : rendez-vous du coiffeur 2 illisibles par la table');

-- Refus : la fiche du client (e-mail) et ses autres réservations.
select is(
  (select count(*)::int from public.utilisateurs where id = '00000c1a-0000-0000-0000-000000000010'),
  0, 'Coiffeur 1 : la ligne du client (e-mail compris) est illisible');
select is(
  (select count(*)::int from public.reservations where client_id = '00000c1a-0000-0000-0000-000000000010'),
  5, 'Coiffeur 1 : par la table, seulement les rendez-vous du client avec lui (5 sur 7)');
select is(
  (select count(*)::int from public.mes_reservations('0000000a-0000-0000-0000-000000000010')),
  0, 'Coiffeur 1 : mes_reservations ne donne pas les réservations de ses clients');

-- ------------------------------------------------------------
-- Refus : coiffeur d'un autre salon
-- ------------------------------------------------------------

select pg_temp.connecter('00000cb1-0000-0000-0000-000000000010');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  'PT403', 'Planning réservé à l''équipe du salon', 'Coiffeur de B : planning du salon A refusé (PT403)');
select is(
  (select count(*)::int from public.reservations where salon_id = '0000000a-0000-0000-0000-000000000010'),
  0, 'Coiffeur de B : rendez-vous du salon A illisibles par la table');
select is(
  (select count(*)::int from public.utilisateurs where id = '00000c1a-0000-0000-0000-000000000010'),
  0, 'Coiffeur de B : la ligne du client est illisible (même s''il a un rendez-vous avec lui)');
select results_eq(
  $$ select id from public.planning('0000000b-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  $$ values ('0000000b-0000-0000-0000-000000000010'::uuid) $$,
  'Coiffeur de B : son propre planning, dans B');

-- ------------------------------------------------------------
-- Refus : client
-- ------------------------------------------------------------

select pg_temp.connecter('00000c1a-0000-0000-0000-000000000010');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  'PT403', 'Planning réservé à l''équipe du salon', 'Client : planning refusé (PT403)');
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13',
                                   '00000c01-0000-0000-0000-000000000010') $$,
  'PT403', 'Planning réservé à l''équipe du salon', 'Client : planning d''un coiffeur refusé (PT403)');
select is(
  (select count(*)::int from public.reservations where client_id <> '00000c1a-0000-0000-0000-000000000010'),
  0, 'Client : aucun rendez-vous d''un autre client lisible par la table');

-- ------------------------------------------------------------
-- Gérant : toute l'équipe de son salon (BF-G5)
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000010');
select results_eq(
  $$ select id, coiffeur_id from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-07') $$,
  $$ values ('00000006-0000-0000-0000-000000000010'::uuid, '00000c01-0000-0000-0000-000000000010'::uuid),
            ('00000001-0000-0000-0000-000000000010'::uuid, '00000c01-0000-0000-0000-000000000010'::uuid),
            ('00000002-0000-0000-0000-000000000010'::uuid, '00000c02-0000-0000-0000-000000000010'::uuid) $$,
  'Gérant A, lundi : les rendez-vous de toute l''équipe, par heure');
select results_eq(
  $$ select id from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-07',
                                    '00000c02-0000-0000-0000-000000000010') $$,
  $$ values ('00000002-0000-0000-0000-000000000010'::uuid) $$,
  'Gérant A : planning d''un coiffeur choisi');
select is(
  (select client_nom from public.planning('0000000a-0000-0000-0000-000000000010', '2030-01-07', '2030-01-07')
    where id = '00000002-0000-0000-0000-000000000010'),
  'Salma'::varchar, 'Gérant A : nom du client dans le planning');
select throws_ok(
  $$ select * from public.planning('0000000b-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13') $$,
  'PT403', 'Planning réservé à l''équipe du salon', 'Gérant A : planning du salon B refusé (PT403)');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000010');
select is(
  (select count(*)::int from public.planning('0000000b-0000-0000-0000-000000000010', '2030-01-07', '2030-01-13')),
  1, 'Gérant B : seulement le salon B');

reset role;
select is(
  (select count(*)::int from public.reservations where id::text like '%-000000000010'),
  7, 'Rien n''a été modifié : 7 réservations');

select * from finish();
rollback;
