-- Issue #102 : « Client arrivé » (marquer_arrivee, arrive_le, planning).
-- Dates relatives au jour du salon (Africa/Tunis) : la règle « le jour du
-- rendez-vous » ne dépend pas du jour où les tests tournent.
begin;

create extension if not exists pgtap with schema extensions;

select plan(22);

-- Jeu de données : salons A et B (Tunis).
--   gA : gérant de A ; c1, c2 : coiffeurs de A ; cl : client de A ;
--   gB : gérant de B.
-- Rendez-vous de A, confirmés sauf mention :
--   j1 (c1) aujourd'hui 00:01 ; j2 (c1) aujourd'hui 00:40, déjà arrivé
--   il y a 5 min ; j3 (c1) demain 10:00 ; j4 (c2) aujourd'hui 00:02 ;
--   t1 (c1) aujourd'hui 02:00, terminé.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000102', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000102', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000102', 'ga@arrive.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000102', 'c1@arrive.test', '{"nom":"Coiffeur 1"}'),
  ('00000c02-0000-0000-0000-000000000102', 'c2@arrive.test', '{"nom":"Coiffeur 2"}'),
  ('00000c1a-0000-0000-0000-000000000102', 'cl@arrive.test', '{"nom":"Salma"}'),
  ('00000b01-0000-0000-0000-000000000102', 'gb@arrive.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000102';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000102', '0000000a-0000-0000-0000-000000000102', 'gerant'),
  ('00000c01-0000-0000-0000-000000000102', '0000000a-0000-0000-0000-000000000102', 'coiffeur'),
  ('00000c02-0000-0000-0000-000000000102', '0000000a-0000-0000-0000-000000000102', 'coiffeur'),
  ('00000c1a-0000-0000-0000-000000000102', '0000000a-0000-0000-0000-000000000102', 'client'),
  ('00000b01-0000-0000-0000-000000000102', '0000000b-0000-0000-0000-000000000102', 'gerant');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('0000f0a1-0000-0000-0000-000000000102', '0000000a-0000-0000-0000-000000000102', 'Coupe', 20, 30);

-- Jour du salon + heure, en timestamptz.
create function pg_temp.a(p_jours integer, p_heure time) returns timestamptz
language sql as $$
  select (((now() at time zone 'Africa/Tunis')::date + p_jours) + p_heure)
         at time zone 'Africa/Tunis' $$;

insert into public.reservations
  (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut, arrive_le)
select r.id::uuid, '0000000a-0000-0000-0000-000000000102', '00000c1a-0000-0000-0000-000000000102',
       r.coiffeur::uuid, '0000f0a1-0000-0000-0000-000000000102',
       pg_temp.a(r.jours, r.heure), pg_temp.a(r.jours, r.heure) + interval '30 minutes',
       r.statut::public.statut_reservation, r.arrive
  from (values
    ('000000a1-0000-0000-0000-000000000102', '00000c01-0000-0000-0000-000000000102', 0, time '00:01', 'confirmee', null::timestamptz),
    ('000000a2-0000-0000-0000-000000000102', '00000c01-0000-0000-0000-000000000102', 0, time '00:40', 'confirmee', now() - interval '5 minutes'),
    ('000000a3-0000-0000-0000-000000000102', '00000c01-0000-0000-0000-000000000102', 1, time '10:00', 'confirmee', null),
    ('000000a4-0000-0000-0000-000000000102', '00000c02-0000-0000-0000-000000000102', 0, time '00:02', 'confirmee', null),
    ('000000d1-0000-0000-0000-000000000102', '00000c01-0000-0000-0000-000000000102', 0, time '02:00', 'terminee', null)
  ) as r(id, coiffeur, jours, heure, statut, arrive);

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ------------------------------------------------------------
-- Structure et droits
-- ------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.marquer_arrivee(uuid, boolean)', 'execute')
  and has_function_privilege('authenticated', 'public.marquer_arrivee(uuid, boolean)', 'execute')
  and not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
     where p.oid = 'public.marquer_arrivee(uuid, boolean)'::regprocedure and a.grantee = 0),
  'marquer_arrivee : exécutable par authenticated seulement (ni public ni anon)');

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
     from pg_proc p where p.oid = 'public.marquer_arrivee(uuid, boolean)'::regprocedure),
  'marquer_arrivee : security definer, search_path fixé');

select ok(
  not has_column_privilege('authenticated', 'public.reservations', 'arrive_le', 'update')
  and not has_column_privilege('anon', 'public.reservations', 'arrive_le', 'update'),
  'arrive_le : aucune écriture directe, seulement par marquer_arrivee');

select ok(
  not has_function_privilege('anon', 'public.planning(uuid, date, date, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.planning(uuid, date, date, uuid)', 'execute'),
  'planning recréée : exécutable par authenticated seulement');

-- ------------------------------------------------------------
-- Sans compte
-- ------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
  $$ select * from public.marquer_arrivee('000000a1-0000-0000-0000-000000000102') $$,
  '42501', null, 'anon : arrivée refusée');

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select * from public.marquer_arrivee('000000a1-0000-0000-0000-000000000102') $$,
  'PT401', 'Connexion requise', 'Sans identifiant : PT401');

-- ------------------------------------------------------------
-- Coiffeur 1
-- ------------------------------------------------------------

select pg_temp.connecter('00000c01-0000-0000-0000-000000000102');

select results_eq(
  $$ select arrive_le from public.marquer_arrivee('000000a1-0000-0000-0000-000000000102') $$,
  $$ values (now()) $$,
  'c1 marque l''arrivée de son rendez-vous du jour : heure du serveur');

select results_eq(
  $$ select arrive_le from public.marquer_arrivee('000000a2-0000-0000-0000-000000000102') $$,
  $$ values (now() - interval '5 minutes') $$,
  'Déjà arrivé : l''heure de la première arrivée est gardée');

select results_eq(
  $$ select r.arrive_le from public.planning('0000000a-0000-0000-0000-000000000102',
       (now() at time zone 'Africa/Tunis')::date, (now() at time zone 'Africa/Tunis')::date) r
      where r.id = '000000a1-0000-0000-0000-000000000102' $$,
  $$ values (now()) $$,
  'planning renvoie l''heure d''arrivée');

select throws_ok(
  $$ select * from public.marquer_arrivee('000000a3-0000-0000-0000-000000000102') $$,
  'PT409', 'Arrivée possible seulement le jour du rendez-vous',
  'Rendez-vous de demain : arrivée refusée (PT409)');

select throws_ok(
  $$ select * from public.marquer_arrivee('000000a4-0000-0000-0000-000000000102') $$,
  'PT404', 'Rendez-vous introuvable',
  'c1 : rendez-vous de c2 refusé (PT404, sans dire lequel)');

select throws_ok(
  $$ select * from public.marquer_arrivee('000000d1-0000-0000-0000-000000000102') $$,
  'PT409', 'Rendez-vous déjà clôturé ou annulé', 'Rendez-vous terminé : refusé (PT409)');

select throws_ok(
  $$ select * from public.marquer_arrivee('000000ff-0000-0000-0000-000000000102') $$,
  'PT404', 'Rendez-vous introuvable', 'Rendez-vous inconnu : PT404');

select throws_ok(
  $$ update public.reservations set arrive_le = now()
      where id = '000000a3-0000-0000-0000-000000000102' $$,
  '42501', null, 'c1 : écriture directe de arrive_le refusée');

-- Règle 4 : un client arrivé n'est pas absent.
select throws_ok(
  $$ update public.reservations set statut = 'absent'
      where id = '000000a1-0000-0000-0000-000000000102' $$,
  'PT409', 'Client arrivé : annulez d''abord son arrivée',
  'Client arrivé : « absent » refusé');

select results_eq(
  $$ select arrive_le from public.marquer_arrivee('000000a1-0000-0000-0000-000000000102', false) $$,
  $$ values (null::timestamptz) $$,
  'c1 annule l''arrivée');

select lives_ok(
  $$ update public.reservations set statut = 'absent'
      where id = '000000a1-0000-0000-0000-000000000102' $$,
  'Arrivée annulée : « absent » accepté');

select throws_ok(
  $$ select * from public.marquer_arrivee('000000a1-0000-0000-0000-000000000102', false) $$,
  'PT409', 'Rendez-vous déjà clôturé ou annulé',
  'Rendez-vous clôturé : l''arrivée ne s''annule plus');

-- ------------------------------------------------------------
-- Gérants
-- ------------------------------------------------------------

select pg_temp.connecter('00000b01-0000-0000-0000-000000000102');
select throws_ok(
  $$ select * from public.marquer_arrivee('000000a4-0000-0000-0000-000000000102') $$,
  'PT404', 'Rendez-vous introuvable', 'Gérant de B : rendez-vous de A refusé (PT404)');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000102');
select results_eq(
  $$ select arrive_le from public.marquer_arrivee('000000a4-0000-0000-0000-000000000102') $$,
  $$ values (now()) $$,
  'Gérant de A : arrivée marquée pour un rendez-vous de c2');

-- Un client arrivé se clôture « terminé » normalement.
select pg_temp.connecter('00000c02-0000-0000-0000-000000000102');
select lives_ok(
  $$ update public.reservations set statut = 'terminee'
      where id = '000000a4-0000-0000-0000-000000000102' $$,
  'Client arrivé : « terminé » accepté');

reset role;
select results_eq(
  $$ select statut::text, arrive_le from public.reservations
      where id = '000000a4-0000-0000-0000-000000000102' $$,
  $$ values ('terminee', now()) $$,
  'Clôture : l''heure d''arrivée est gardée');

select * from finish();
rollback;
