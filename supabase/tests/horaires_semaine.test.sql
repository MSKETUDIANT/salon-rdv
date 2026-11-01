-- Issue #151 (option B) : definir_semaine(), toutes les plages de la semaine
-- d'un coiffeur enregistrées en une fois, tout ou rien.
begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

-- Salons A et B ; gA gérant de A, cA coiffeur de A, gB gérant de B.
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000151', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000151', 'Salon B');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000151', 'ga@semaine.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000151', 'ca@semaine.test', '{"nom":"Coiffeur A"}'),
  ('00000b01-0000-0000-0000-000000000151', 'gb@semaine.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000151';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000151', '0000000a-0000-0000-0000-000000000151', 'gerant'),
  ('00000c01-0000-0000-0000-000000000151', '0000000a-0000-0000-0000-000000000151', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000151', '0000000b-0000-0000-0000-000000000151', 'gerant');

-- Une plage existante : lundi 08:00-12:00.
insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('0000000a-0000-0000-0000-000000000151', '00000c01-0000-0000-0000-000000000151', 1, '08:00', '12:00');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Plages du coiffeur A : « jour 09:00-18:00 », triées.
create function pg_temp.plages() returns text[] language sql as $$
  select coalesce(array_agg(jour_semaine || ' ' || to_char(heure_debut, 'HH24:MI') || '-'
                            || to_char(heure_fin, 'HH24:MI')
                            order by jour_semaine, heure_debut), '{}')
    from public.horaires where coiffeur_id = '00000c01-0000-0000-0000-000000000151';
$$;

-- Appel de la fonction pour le coiffeur A du salon A.
create function pg_temp.semaine(p_plages text) returns void language sql as $$
  select public.definir_semaine('0000000a-0000-0000-0000-000000000151',
                                '00000c01-0000-0000-0000-000000000151', p_plages::jsonb);
$$;

set local role authenticated;

-- ------------------------------------------------------------
-- Droits
-- ------------------------------------------------------------

select throws_ok($$ select pg_temp.semaine('[]') $$, 'PT401', null, 'Sans identité : refusé');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000151');
select throws_ok($$ select pg_temp.semaine('[]') $$, '42501', null,
  'Un coiffeur ne règle pas les horaires');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000151');
select throws_ok($$ select pg_temp.semaine('[]') $$, '42501', null,
  'Le gérant d''un autre salon non plus');

reset role;
select is(pg_temp.plages(), array['1 08:00-12:00'], 'Refus : la plage existante reste');
set local role authenticated;

-- ------------------------------------------------------------
-- Saisie
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000151');

select throws_ok($$ select pg_temp.semaine('{"jour":1}') $$, 'PT400', 'Horaires invalides',
  'Pas une liste : refusé');
select throws_ok($$ select pg_temp.semaine('[{"jour":8,"debut":"09:00","fin":"18:00"}]') $$,
  'PT400', 'Horaires invalides', 'Jour hors de 1 à 7 : refusé');
select throws_ok($$ select pg_temp.semaine('[{"jour":2,"debut":"neuf","fin":"18:00"}]') $$,
  'PT400', 'Horaires invalides', 'Heure illisible : refusé');
select throws_ok($$ select pg_temp.semaine('[{"jour":3,"debut":"18:00","fin":"09:00"}]') $$,
  'PT400', 'La fin doit être après le début le mercredi', 'Fin avant le début : jour nommé');

-- ------------------------------------------------------------
-- Semaine enregistrée en une fois
-- ------------------------------------------------------------

select lives_ok($$ select pg_temp.semaine('[
    {"jour":1,"debut":"09:00","fin":"13:00"}, {"jour":1,"debut":"14:00","fin":"19:00"},
    {"jour":2,"debut":"09:00","fin":"18:00"}, {"jour":3,"debut":"09:00","fin":"18:00"},
    {"jour":4,"debut":"09:00","fin":"18:00"}, {"jour":5,"debut":"09:00","fin":"18:00"}]') $$,
  'Semaine avec une pause le lundi');

select is(pg_temp.plages(),
  array['1 09:00-13:00', '1 14:00-19:00', '2 09:00-18:00', '3 09:00-18:00',
        '4 09:00-18:00', '5 09:00-18:00'],
  'L''ancienne plage du lundi est remplacée, la semaine est celle reçue');

-- Plages bout à bout : acceptées.
select lives_ok($$ select pg_temp.semaine('[
    {"jour":6,"debut":"09:00","fin":"13:00"}, {"jour":6,"debut":"13:00","fin":"17:00"}]') $$,
  'Deux plages bout à bout le samedi : acceptées');
select is(pg_temp.plages(), array['6 09:00-13:00', '6 13:00-17:00'],
  'Jours absents de la liste : ne travaille pas');

-- Chevauchement le mardi : rien ne change.
select throws_ok($$ select pg_temp.semaine('[
    {"jour":1,"debut":"09:00","fin":"18:00"},
    {"jour":2,"debut":"09:00","fin":"13:00"}, {"jour":2,"debut":"12:00","fin":"18:00"}]') $$,
  'PT409', 'Deux plages se chevauchent le mardi', 'Chevauchement : le jour est nommé');
select is(pg_temp.plages(), array['6 09:00-13:00', '6 13:00-17:00'],
  'Chevauchement : les plages d''avant restent (tout ou rien)');

-- Liste vide : le coiffeur ne travaille plus aucun jour.
select pg_temp.semaine('[]');
select is(pg_temp.plages(), '{}'::text[], 'Liste vide : plus aucune plage');

select * from finish();
rollback;
