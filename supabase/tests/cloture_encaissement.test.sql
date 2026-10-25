-- Issue #11 : clôture d'un rendez-vous, client absent, encaissement,
-- historique (BF-K3, BF-K4, BF-G4). Dates relatives à now() : les règles de
-- temps (« commencé ») ne dépendent pas du jour où les tests tournent.
begin;

create extension if not exists pgtap with schema extensions;

select plan(42);

-- Jeu de données : salons A et B (Tunis).
--   gA : gérant de A ; c1, c2 : coiffeurs de A ; cl : client de A ;
--   gB : gérant de B.
-- Rendez-vous de A (c1 sauf mention) :
--   p1 hier, p2 avant-hier, p5 il y a 3 jours : confirmés, passés ;
--   e1 en cours (commencé il y a 10 min) ; f1 dans 2 jours ;
--   p3, p4 (c2) passés ; f3 (c2) dans 2 jours ;
--   ab il y a 4 jours, absent ; t1, t2 il y a 5 et 6 jours, terminés.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000011', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000011', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000011', 'ga@cloture.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000011', 'c1@cloture.test', '{"nom":"Coiffeur 1"}'),
  ('00000c02-0000-0000-0000-000000000011', 'c2@cloture.test', '{"nom":"Coiffeur 2"}'),
  ('00000c1a-0000-0000-0000-000000000011', 'cl@cloture.test', '{"nom":"Salma"}'),
  ('00000b01-0000-0000-0000-000000000011', 'gb@cloture.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000011';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000011', '0000000a-0000-0000-0000-000000000011', 'gerant'),
  ('00000c01-0000-0000-0000-000000000011', '0000000a-0000-0000-0000-000000000011', 'coiffeur'),
  ('00000c02-0000-0000-0000-000000000011', '0000000a-0000-0000-0000-000000000011', 'coiffeur'),
  ('00000c1a-0000-0000-0000-000000000011', '0000000a-0000-0000-0000-000000000011', 'client'),
  ('00000b01-0000-0000-0000-000000000011', '0000000b-0000-0000-0000-000000000011', 'gerant');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('0000f0a1-0000-0000-0000-000000000011', '0000000a-0000-0000-0000-000000000011', 'Coupe', 20, 30);

insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut)
select r.id::uuid, '0000000a-0000-0000-0000-000000000011', '00000c1a-0000-0000-0000-000000000011',
       r.coiffeur::uuid, '0000f0a1-0000-0000-0000-000000000011',
       now() + r.decalage, now() + r.decalage + interval '30 minutes',
       r.statut::public.statut_reservation
  from (values
    ('000000f1-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-1 day',     'confirmee'),
    ('000000f2-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-2 days',    'confirmee'),
    ('000000f5-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-3 days',    'confirmee'),
    ('000000e1-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-10 minutes', 'confirmee'),
    ('0000001f-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '2 days',     'confirmee'),
    ('000000f3-0000-0000-0000-000000000011', '00000c02-0000-0000-0000-000000000011', interval '-1 day',     'confirmee'),
    ('000000f4-0000-0000-0000-000000000011', '00000c02-0000-0000-0000-000000000011', interval '-2 days',    'confirmee'),
    ('0000003f-0000-0000-0000-000000000011', '00000c02-0000-0000-0000-000000000011', interval '2 days',     'confirmee'),
    ('000000ab-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-4 days',    'absent'),
    ('000000d1-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-5 days',    'terminee'),
    ('000000d2-0000-0000-0000-000000000011', '00000c01-0000-0000-0000-000000000011', interval '-6 days',    'terminee')
  ) as r(id, coiffeur, decalage, statut);

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Bornes de l'historique : les 10 derniers jours, à l'heure du salon.
create function pg_temp.du() returns date language sql as $$
  select (now() at time zone 'Africa/Tunis')::date - 10 $$;
create function pg_temp.au() returns date language sql as $$
  select (now() at time zone 'Africa/Tunis')::date $$;

-- ------------------------------------------------------------
-- Structure et droits d'exécution
-- ------------------------------------------------------------

select ok(
  not has_function_privilege('anon', 'public.planning(uuid, date, date, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.planning(uuid, date, date, uuid)', 'execute')
  and not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
     where p.oid = 'public.planning(uuid, date, date, uuid)'::regprocedure and a.grantee = 0),
  'planning recréée : exécutable par authenticated seulement (ni public ni anon)');

select ok(
  not has_function_privilege('anon', 'public.historique(uuid, date, date, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.historique(uuid, date, date, uuid)', 'execute')
  and not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
     where p.oid = 'public.historique(uuid, date, date, uuid)'::regprocedure and a.grantee = 0),
  'historique : exécutable par authenticated seulement (ni public ni anon)');

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
     from pg_proc p where p.oid = 'public.historique(uuid, date, date, uuid)'::regprocedure),
  'historique : security definer, search_path fixé');

select ok(
  exists (select 1 from pg_constraint
           where conname = 'encaissements_montant_positif'
             and conrelid = 'public.encaissements'::regclass),
  'encaissements : contrainte montant >= 0 présente');

-- ------------------------------------------------------------
-- Sans compte (anon)
-- ------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
  $$ select * from public.planning('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  '42501', null, 'anon : planning refusé');
select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  '42501', null, 'anon : historique refusé');
reset role;

-- ------------------------------------------------------------
-- Coiffeur 1 : clôture de ses rendez-vous (BF-K3, BF-K4)
-- ------------------------------------------------------------

set local role authenticated;
select pg_temp.connecter('00000c01-0000-0000-0000-000000000011');

select lives_ok(
  $$ update public.reservations set statut = 'terminee' where id = '000000f1-0000-0000-0000-000000000011' $$,
  'Coiffeur 1 : marque terminé un rendez-vous passé');

select lives_ok(
  $$ update public.reservations set statut = 'absent' where id = '000000f2-0000-0000-0000-000000000011' $$,
  'Coiffeur 1 : marque absent le client d''un rendez-vous passé');

select lives_ok(
  $$ update public.reservations set statut = 'terminee' where id = '000000e1-0000-0000-0000-000000000011' $$,
  'Coiffeur 1 : marque terminé un rendez-vous en cours (commencé)');

select throws_ok(
  $$ update public.reservations set statut = 'terminee' where id = '0000001f-0000-0000-0000-000000000011' $$,
  'PT409', 'Rendez-vous pas encore commencé', 'Coiffeur 1 : terminé avant le début refusé (PT409)');

select throws_ok(
  $$ update public.reservations set statut = 'absent' where id = '0000001f-0000-0000-0000-000000000011' $$,
  'PT409', 'Rendez-vous pas encore commencé', 'Coiffeur 1 : absent avant le début refusé (PT409)');

select results_eq(
  $$ with m as (
       update public.reservations set statut = 'terminee' where id = '000000f3-0000-0000-0000-000000000011'
       returning 1)
     select count(*)::int from m $$,
  $$ values (0) $$,
  'Coiffeur 1 : clôturer le rendez-vous du coiffeur 2 sans effet (0 ligne)');

select throws_ok(
  $$ update public.reservations set statut = 'confirmee' where id = '000000d1-0000-0000-0000-000000000011' $$,
  '23514', 'Transition de statut interdite : terminee -> confirmee',
  'Coiffeur 1 : remettre « confirmé » un rendez-vous terminé refusé (trigger)');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000d2-0000-0000-0000-000000000011', 20, '00000c01-0000-0000-0000-000000000011') $$,
  '42501', null, 'Coiffeur 1 : encaisser refusé (BF-G4)');

select is(
  (select montant_encaisse from public.planning('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au())
    where id = '000000d1-0000-0000-0000-000000000011'),
  null::numeric, 'Coiffeur 1 : planning sans montant encaissé');

select is(
  (select prix from public.planning('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au())
    where id = '000000d1-0000-0000-0000-000000000011'),
  20.000, 'Coiffeur 1 : planning avec le prix de la prestation');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  'PT403', 'Historique réservé au gérant du salon', 'Coiffeur 1 : historique refusé (PT403)');

-- ------------------------------------------------------------
-- Client
-- ------------------------------------------------------------

select pg_temp.connecter('00000c1a-0000-0000-0000-000000000011');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  'PT403', 'Historique réservé au gérant du salon', 'Client : historique refusé (PT403)');

-- ------------------------------------------------------------
-- Gérant A : clôture pour un coiffeur, encaissement (BF-G4)
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000011');

select lives_ok(
  $$ update public.reservations set statut = 'terminee' where id = '000000f4-0000-0000-0000-000000000011' $$,
  'Gérant A : clôture le rendez-vous passé du coiffeur 2');

select throws_ok(
  $$ update public.reservations set statut = 'absent' where id = '0000003f-0000-0000-0000-000000000011' $$,
  'PT409', 'Rendez-vous pas encore commencé', 'Gérant A : absent avant le début refusé (PT409)');

select lives_ok(
  $$ insert into public.encaissements (id, reservation_id, montant, encaisse_par)
     values ('0000e001-0000-0000-0000-000000000011', '000000d1-0000-0000-0000-000000000011', 18.500,
             '00000a01-0000-0000-0000-000000000011') $$,
  'Gérant A : encaisse un rendez-vous terminé (montant modifié : 18,500)');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000d1-0000-0000-0000-000000000011', 20, '00000a01-0000-0000-0000-000000000011') $$,
  '23505', null, 'Gérant A : deuxième encaissement du même rendez-vous refusé');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000ab-0000-0000-0000-000000000011', 20, '00000a01-0000-0000-0000-000000000011') $$,
  'PT409', 'Seul un rendez-vous terminé est encaissable', 'Gérant A : encaisser un client absent refusé (BF-K4)');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000f5-0000-0000-0000-000000000011', 20, '00000a01-0000-0000-0000-000000000011') $$,
  'PT409', 'Seul un rendez-vous terminé est encaissable', 'Gérant A : encaisser un rendez-vous confirmé refusé');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000d2-0000-0000-0000-000000000011', -1, '00000a01-0000-0000-0000-000000000011') $$,
  '23514', null, 'Gérant A : montant négatif refusé (contrainte)');

select lives_ok(
  $$ update public.encaissements set montant = 19 where id = '0000e001-0000-0000-0000-000000000011' $$,
  'Gérant A : corrige le montant');

select throws_ok(
  $$ update public.encaissements set encaisse_par = '00000c01-0000-0000-0000-000000000011'
      where id = '0000e001-0000-0000-0000-000000000011' $$,
  '42501', null, 'Gérant A : modifier encaisse_par refusé (montant seulement)');

select throws_ok(
  $$ update public.encaissements set reservation_id = '000000d2-0000-0000-0000-000000000011'
      where id = '0000e001-0000-0000-0000-000000000011' $$,
  '42501', null, 'Gérant A : déplacer un encaissement refusé (montant seulement)');

select is(
  (select montant_encaisse from public.planning('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au())
    where id = '000000d1-0000-0000-0000-000000000011'),
  19.000, 'Gérant A : planning avec le montant encaissé');

-- Historique : terminés et absents seulement, dans l'ordre ; montant si encaissé.
select results_eq(
  $$ select id, statut::text, montant from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  $$ values ('000000d2-0000-0000-0000-000000000011'::uuid, 'terminee', null::numeric),
            ('000000d1-0000-0000-0000-000000000011'::uuid, 'terminee', 19.000),
            ('000000ab-0000-0000-0000-000000000011'::uuid, 'absent',   null),
            ('000000f2-0000-0000-0000-000000000011'::uuid, 'absent',   null),
            ('000000f4-0000-0000-0000-000000000011'::uuid, 'terminee', null),
            ('000000f1-0000-0000-0000-000000000011'::uuid, 'terminee', null),
            ('000000e1-0000-0000-0000-000000000011'::uuid, 'terminee', null) $$,
  'Gérant A : historique des 10 derniers jours (terminés et absents, ni confirmés ni futurs)');

select results_eq(
  $$ select id from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au(),
                                      '00000c02-0000-0000-0000-000000000011') $$,
  $$ values ('000000f4-0000-0000-0000-000000000011'::uuid) $$,
  'Gérant A : historique filtré sur le coiffeur 2');

select results_eq(
  $$ select coiffeur, prestation, prix, client_nom, encaisse_le is not null
       from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au())
      where id = '000000d1-0000-0000-0000-000000000011' $$,
  $$ values ('Coiffeur 1'::varchar, 'Coupe'::varchar, 20.000, 'Salma'::varchar, true) $$,
  'Gérant A : historique avec coiffeur, prestation, prix, client et date d''encaissement');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.au() - 31, pg_temp.au()) $$,
  'PT400', 'Période de 1 à 31 jours', 'Gérant A : historique sur 32 jours refusé (PT400)');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.au(), pg_temp.du()) $$,
  'PT400', 'Période de 1 à 31 jours', 'Gérant A : historique à l''envers refusé (PT400)');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', null, pg_temp.au()) $$,
  'PT400', 'Période de 1 à 31 jours', 'Gérant A : historique sans date de début refusé (PT400)');

-- ------------------------------------------------------------
-- Gérant B : rien dans A
-- ------------------------------------------------------------

select pg_temp.connecter('00000b01-0000-0000-0000-000000000011');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000d2-0000-0000-0000-000000000011', 20, '00000b01-0000-0000-0000-000000000011') $$,
  '42501', null, 'Gérant B : encaisser un rendez-vous de A refusé');

select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  'PT403', 'Historique réservé au gérant du salon', 'Gérant B : historique de A refusé (PT403)');

-- Connecté sans identifiant.
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select * from public.historique('0000000a-0000-0000-0000-000000000011', pg_temp.du(), pg_temp.au()) $$,
  'PT401', 'Connexion requise', 'Sans identifiant : historique PT401');

-- ------------------------------------------------------------
-- Hors API (postgres) : mêmes règles
-- ------------------------------------------------------------

reset role;

select throws_ok(
  $$ update public.reservations set statut = 'terminee' where id = '0000001f-0000-0000-0000-000000000011' $$,
  'PT409', 'Rendez-vous pas encore commencé', 'Hors API : terminé avant le début refusé aussi');

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('000000ab-0000-0000-0000-000000000011', 20, '00000a01-0000-0000-0000-000000000011') $$,
  'PT409', 'Seul un rendez-vous terminé est encaissable', 'Hors API : encaisser un client absent refusé aussi');

select results_eq(
  $$ select id, statut::text from public.reservations
      where id in ('000000f1-0000-0000-0000-000000000011', '000000f2-0000-0000-0000-000000000011',
                   '000000f3-0000-0000-0000-000000000011', '000000f4-0000-0000-0000-000000000011',
                   '0000001f-0000-0000-0000-000000000011', '0000003f-0000-0000-0000-000000000011',
                   '000000e1-0000-0000-0000-000000000011', '000000d1-0000-0000-0000-000000000011')
      order by id $$,
  $$ values ('0000001f-0000-0000-0000-000000000011'::uuid, 'confirmee'),
            ('0000003f-0000-0000-0000-000000000011'::uuid, 'confirmee'),
            ('000000d1-0000-0000-0000-000000000011'::uuid, 'terminee'),
            ('000000e1-0000-0000-0000-000000000011'::uuid, 'terminee'),
            ('000000f1-0000-0000-0000-000000000011'::uuid, 'terminee'),
            ('000000f2-0000-0000-0000-000000000011'::uuid, 'absent'),
            ('000000f3-0000-0000-0000-000000000011'::uuid, 'confirmee'),
            ('000000f4-0000-0000-0000-000000000011'::uuid, 'terminee') $$,
  'Statuts finaux : seules les clôtures autorisées ont eu lieu');

select results_eq(
  $$ select reservation_id, montant, encaisse_par from public.encaissements
      where reservation_id::text like '%-000000000011' $$,
  $$ values ('000000d1-0000-0000-0000-000000000011'::uuid, 19.000, '00000a01-0000-0000-0000-000000000011'::uuid) $$,
  'Encaissements : un seul, montant corrigé, encaissé par le gérant A');

select * from finish();

rollback;
