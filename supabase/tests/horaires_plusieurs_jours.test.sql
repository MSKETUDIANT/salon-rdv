-- Issue #151 : definir_plages(), même plage sur plusieurs jours, tout ou
-- rien, modification d'une plage.
begin;

create extension if not exists pgtap with schema extensions;

select plan(14);

-- Salons A et B ; gA gérant de A, cA coiffeur de A, gB gérant de B.
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000151', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000151', 'Salon B');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000151', 'ga@plages.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000151', 'ca@plages.test', '{"nom":"Coiffeur A"}'),
  ('00000b01-0000-0000-0000-000000000151', 'gb@plages.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000151';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000151', '0000000a-0000-0000-0000-000000000151', 'gerant'),
  ('00000c01-0000-0000-0000-000000000151', '0000000a-0000-0000-0000-000000000151', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000151', '0000000b-0000-0000-0000-000000000151', 'gerant');

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

set local role authenticated;

-- ------------------------------------------------------------
-- Droits
-- ------------------------------------------------------------

select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1], '09:00', '18:00') $$,
  'PT401', null, 'Sans identité : refusé');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000151');
select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1], '09:00', '18:00') $$,
  '42501', null, 'Un coiffeur ne règle pas les horaires');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000151');
select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1], '09:00', '18:00') $$,
  '42501', null, 'Le gérant d''un autre salon non plus');

-- ------------------------------------------------------------
-- Saisie
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000151');

select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[]::integer[], '09:00', '18:00') $$,
  'PT400', 'Choisissez au moins un jour', 'Aucun jour : message clair');

select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1, 8], '09:00', '18:00') $$,
  'PT400', 'Jour invalide', 'Jour hors de 1 à 7 : refusé');

select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1], '18:00', '09:00') $$,
  'PT400', 'La fin doit être après le début', 'Fin avant le début : message clair');

-- ------------------------------------------------------------
-- Plusieurs jours d'un coup
-- ------------------------------------------------------------

select lives_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[5, 1, 2, 3, 4, 1], '09:00', '13:00') $$,
  'Du lundi au vendredi, 9 h – 13 h (doublon ignoré)');

select is(pg_temp.plages(),
  array['1 09:00-13:00', '2 09:00-13:00', '3 09:00-13:00', '4 09:00-13:00', '5 09:00-13:00'],
  'Cinq plages créées, une par jour');

-- Après-midi : bout à bout avec le matin, accepté.
select lives_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[1, 2], '13:00', '18:00') $$,
  'Après-midi bout à bout avec le matin : accepté');

-- Chevauchement le mercredi : rien n'est créé, ni jeudi ni samedi.
select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[3, 4, 6], '12:00', '15:00') $$,
  'PT409', 'Chevauche une plage existante le mercredi', 'Chevauchement : le jour est nommé');

select is(cardinality(pg_temp.plages()), 7, 'Chevauchement : aucune plage créée (tout ou rien)');

-- ------------------------------------------------------------
-- Modification d'une plage (et copie sur d'autres jours)
-- ------------------------------------------------------------

select lives_ok(
  format($$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[3, 6], '10:00', '14:00', %L) $$,
    (select id from public.horaires
      where coiffeur_id = '00000c01-0000-0000-0000-000000000151' and jour_semaine = 3)),
  'Mercredi passe à 10 h – 14 h, copié le samedi');

select is(pg_temp.plages(),
  array['1 09:00-13:00', '1 13:00-18:00', '2 09:00-13:00', '2 13:00-18:00',
        '3 10:00-14:00', '4 09:00-13:00', '5 09:00-13:00', '6 10:00-14:00'],
  'Ancienne plage du mercredi remplacée, samedi ajouté');

-- Plage d'un autre coiffeur ou inexistante : introuvable, rien ne change.
select throws_ok(
  $$ select public.definir_plages('0000000a-0000-0000-0000-000000000151',
       '00000c01-0000-0000-0000-000000000151', array[7], '10:00', '14:00',
       '00000000-0000-0000-0000-000000000000') $$,
  'PT404', 'Plage introuvable', 'Plage à remplacer introuvable : refus');

select * from finish();
rollback;
