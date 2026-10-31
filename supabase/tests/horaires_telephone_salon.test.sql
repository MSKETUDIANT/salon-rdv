-- Issue #129 (PR 2) : horaires d'ouverture du salon (horaires_du_salon) et
-- téléphone (salons.telephone, definir_telephone_salon).
begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

-- Jeu de données : salons A et B.
--   gA : gérant de A ; c1, c2 : coiffeurs de A ; ex : ancien coiffeur de A
--   (horaires restés, plus de rôle) ; gB : gérant de B.
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000129', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000129', 'Salon B');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000129', 'ga@tel.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000129', 'c1@tel.test', '{"nom":"Coiffeur 1"}'),
  ('00000c02-0000-0000-0000-000000000129', 'c2@tel.test', '{"nom":"Coiffeur 2"}'),
  ('00000e01-0000-0000-0000-000000000129', 'ex@tel.test', '{"nom":"Ancien"}'),
  ('00000b01-0000-0000-0000-000000000129', 'gb@tel.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000129';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000129', '0000000a-0000-0000-0000-000000000129', 'gerant'),
  ('00000c01-0000-0000-0000-000000000129', '0000000a-0000-0000-0000-000000000129', 'coiffeur'),
  ('00000c02-0000-0000-0000-000000000129', '0000000a-0000-0000-0000-000000000129', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000129', '0000000b-0000-0000-0000-000000000129', 'gerant');

-- Lundi : c1 9 h – 13 h et 14 h – 17 h, c2 10 h – 19 h → 9 h – 19 h.
-- Mardi : c2 seul, 10 h – 18 h. Mercredi : seulement l'ancien coiffeur → fermé.
insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('0000000a-0000-0000-0000-000000000129', '00000c01-0000-0000-0000-000000000129', 1, '09:00', '13:00'),
  ('0000000a-0000-0000-0000-000000000129', '00000c01-0000-0000-0000-000000000129', 1, '14:00', '17:00'),
  ('0000000a-0000-0000-0000-000000000129', '00000c02-0000-0000-0000-000000000129', 1, '10:00', '19:00'),
  ('0000000a-0000-0000-0000-000000000129', '00000c02-0000-0000-0000-000000000129', 2, '10:00', '18:00'),
  ('0000000a-0000-0000-0000-000000000129', '00000e01-0000-0000-0000-000000000129', 3, '08:00', '20:00');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ------------------------------------------------------------
-- horaires_du_salon
-- ------------------------------------------------------------

set local role anon;

select results_eq(
  $$ select jour_semaine, ouverture, fermeture
       from public.horaires_du_salon('0000000a-0000-0000-0000-000000000129') $$,
  $$ values (1, '09:00'::time, '19:00'::time), (2, '10:00'::time, '18:00'::time) $$,
  'Sans compte : première arrivée et dernier départ par jour, anciens coiffeurs exclus');

select is_empty(
  $$ select * from public.horaires_du_salon('0000000b-0000-0000-0000-000000000129') $$,
  'Salon sans horaires : aucune ligne (fermé tous les jours)');

-- ------------------------------------------------------------
-- salons.telephone : contrainte
-- ------------------------------------------------------------

reset role;

select is(
  (select telephone from public.salons where id = '0000000a-0000-0000-0000-000000000129'),
  null, 'Pas de numéro par défaut');

select lives_ok(
  $$ update public.salons set telephone = '+216 71.234-567'
      where id = '0000000a-0000-0000-0000-000000000129' $$,
  'Contrainte : « + » au début, espaces, points et tirets acceptés');

select throws_ok(
  $$ update public.salons set telephone = '1234567'
      where id = '0000000a-0000-0000-0000-000000000129' $$,
  '23514', null, 'Contrainte : 8 chiffres au moins');

select throws_ok(
  $$ update public.salons set telephone = '1234567890123456'
      where id = '0000000a-0000-0000-0000-000000000129' $$,
  '23514', null, 'Contrainte : 15 chiffres au plus');

select throws_ok(
  $$ update public.salons set telephone = '71 234 567 poste 2'
      where id = '0000000a-0000-0000-0000-000000000129' $$,
  '23514', null, 'Contrainte : pas de lettres');

select throws_ok(
  $$ update public.salons set telephone = '71 2+34 567'
      where id = '0000000a-0000-0000-0000-000000000129' $$,
  '23514', null, 'Contrainte : « + » seulement au début');

-- ------------------------------------------------------------
-- definir_telephone_salon
-- ------------------------------------------------------------

set local role anon;

select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '71 234 567') $$,
  '42501', null, 'Sans compte : pas le droit d''appeler la fonction');

set local role authenticated;

select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '71 234 567') $$,
  'PT401', null, 'Connecté sans identité : refusé');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000129');
select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '71 234 567') $$,
  'PT403', null, 'Un coiffeur ne règle pas le numéro');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000129');
select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '71 234 567') $$,
  'PT403', null, 'Le gérant d''un autre salon ne règle pas le numéro');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000129');

select results_eq(
  $$ select * from public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '  71   234 567 ') $$,
  $$ values ('71 234 567'::text) $$,
  'Le gérant règle le numéro, espaces en trop retirés');

select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '12 34') $$,
  'PT400', 'Numéro de téléphone invalide', 'Numéro trop court : message clair');

select throws_ok(
  $$ select public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', 'abc') $$,
  'PT400', 'Numéro de téléphone invalide', 'Lettres : message clair');

-- Aucune policy UPDATE sur salons : l'écriture directe ne touche aucune ligne.
select results_eq(
  $$ with m as (
       update public.salons set telephone = '00 00 00 00'
        where id = '0000000a-0000-0000-0000-000000000129' returning 1)
     select count(*)::integer from m $$,
  $$ values (0) $$,
  'Le gérant n''écrit pas directement dans salons');

reset role;
select is(
  (select telephone from public.salons where id = '0000000a-0000-0000-0000-000000000129'),
  '71 234 567', 'Numéro enregistré');

set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000129');
select results_eq(
  $$ select * from public.definir_telephone_salon('0000000a-0000-0000-0000-000000000129', '   ') $$,
  $$ values (null::text) $$,
  'Vide : le numéro est retiré');

reset role;
select is(
  (select telephone from public.salons where id = '0000000a-0000-0000-0000-000000000129'),
  null, 'Numéro retiré en base');

-- Lisible sans compte, comme le nom et l'adresse.
update public.salons set telephone = '71 234 567'
 where id = '0000000a-0000-0000-0000-000000000129';
set local role anon;
select is(
  (select telephone from public.salons where id = '0000000a-0000-0000-0000-000000000129'),
  '71 234 567', 'Sans compte : le numéro se lit');

select * from finish();
rollback;
