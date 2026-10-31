-- Issue #118 : délai minimum d'annulation, réglable par le gérant
-- (salons.delai_annulation_minutes, definir_delai_annulation, règle
-- « annulable » avec le délai). Dates relatives à now().
begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

-- Jeu de données : salons A et B.
--   gA : gérant de A ; c1 : coiffeur de A ; cl : client ; gB : gérant de B.
-- Réservations de cl dans A (c1, confirmées) : d1 dans 1 h, d3 dans 3 h.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000118', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000118', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000118', 'ga@delai.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000118', 'c1@delai.test', '{"nom":"Coiffeur 1"}'),
  ('00000c1a-0000-0000-0000-000000000118', 'cl@delai.test', '{"nom":"Salma"}'),
  ('00000b01-0000-0000-0000-000000000118', 'gb@delai.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000118';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118', 'gerant'),
  ('00000c01-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118', 'coiffeur'),
  ('00000c1a-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118', 'client'),
  ('00000b01-0000-0000-0000-000000000118', '0000000b-0000-0000-0000-000000000118', 'gerant');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('0000f0a1-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118', 'Coupe', 20, 30);

insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
values
  ('000000d1-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118',
   '00000c1a-0000-0000-0000-000000000118', '00000c01-0000-0000-0000-000000000118',
   '0000f0a1-0000-0000-0000-000000000118', now() + interval '1 hour', now() + interval '90 minutes'),
  ('000000d3-0000-0000-0000-000000000118', '0000000a-0000-0000-0000-000000000118',
   '00000c1a-0000-0000-0000-000000000118', '00000c01-0000-0000-0000-000000000118',
   '0000f0a1-0000-0000-0000-000000000118', now() + interval '3 hours', now() + interval '210 minutes');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ------------------------------------------------------------
-- Structure
-- ------------------------------------------------------------

select results_eq(
  $$ select delai_annulation_minutes from public.salons
      where id = '0000000a-0000-0000-0000-000000000118' $$,
  $$ values (0) $$,
  'Délai par défaut : 0 (comportement inchangé)');

select throws_ok(
  $$ update public.salons set delai_annulation_minutes = 10081
      where id = '0000000a-0000-0000-0000-000000000118' $$,
  '23514', null, 'Contrainte : 7 jours au plus');

select ok(
  not has_function_privilege('anon', 'public.definir_delai_annulation(uuid, integer)', 'execute')
  and has_function_privilege('authenticated', 'public.definir_delai_annulation(uuid, integer)', 'execute'),
  'definir_delai_annulation : exécutable par authenticated seulement');

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
     from pg_proc p where p.oid = 'public.definir_delai_annulation(uuid, integer)'::regprocedure),
  'definir_delai_annulation : security definer, search_path fixé');

-- ------------------------------------------------------------
-- Règle commune avec le délai
-- ------------------------------------------------------------

select ok(
  private.reservation_annulable('confirmee', now() + interval '3 hours', 120)
  and not private.reservation_annulable('confirmee', now() + interval '1 hour', 120)
  and private.reservation_annulable('confirmee', now() + interval '1 hour'),
  'Règle commune : délai pris en compte ; sans délai, comme avant');

-- ------------------------------------------------------------
-- Réglage du délai
-- ------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select * from public.definir_delai_annulation('0000000a-0000-0000-0000-000000000118', 120) $$,
  'PT401', 'Connexion requise', 'Sans identifiant : PT401');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000118');
select throws_ok(
  $$ select * from public.definir_delai_annulation('0000000a-0000-0000-0000-000000000118', 120) $$,
  'PT403', 'Réglage réservé au gérant du salon', 'Coiffeur : refusé (PT403)');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000118');
select throws_ok(
  $$ select * from public.definir_delai_annulation('0000000a-0000-0000-0000-000000000118', 120) $$,
  'PT403', 'Réglage réservé au gérant du salon', 'Gérant de B : salon A refusé (PT403)');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000118');
select throws_ok(
  $$ select * from public.definir_delai_annulation('0000000a-0000-0000-0000-000000000118', -1) $$,
  'PT400', 'Délai de 0 à 7 jours', 'Délai négatif : refusé (PT400)');
select throws_ok(
  $$ select * from public.definir_delai_annulation('0000000a-0000-0000-0000-000000000118', 10081) $$,
  'PT400', 'Délai de 0 à 7 jours', 'Plus de 7 jours : refusé (PT400)');

select results_eq(
  $$ select delai_annulation_minutes from public.definir_delai_annulation(
       '0000000a-0000-0000-0000-000000000118', 120) $$,
  $$ values (120) $$,
  'Gérant de A : délai de 2 h enregistré');

select results_eq(
  $$ with m as (update public.salons set delai_annulation_minutes = 0
                 where id = '0000000a-0000-0000-0000-000000000118' returning 1)
     select count(*)::int from m $$,
  $$ values (0) $$,
  'Gérant : écriture directe sur salons sans effet (RLS)');

-- ------------------------------------------------------------
-- Client : annulation avec un délai de 2 h
-- ------------------------------------------------------------

select pg_temp.connecter('00000c1a-0000-0000-0000-000000000118');

select results_eq(
  $$ select id, annulable from public.mes_reservations('0000000a-0000-0000-0000-000000000118') $$,
  $$ values ('000000d1-0000-0000-0000-000000000118'::uuid, false),
            ('000000d3-0000-0000-0000-000000000118'::uuid, true) $$,
  'Délai 2 h : dans 1 h non annulable, dans 3 h annulable');

select throws_ok(
  $$ select * from public.annuler_reservation('000000d1-0000-0000-0000-000000000118') $$,
  'PT409', 'Cette réservation ne peut plus être annulée',
  'Délai 2 h : annulation du rendez-vous dans 1 h refusée (PT409)');

select results_eq(
  $$ select statut::text from public.annuler_reservation('000000d3-0000-0000-0000-000000000118') $$,
  $$ values ('annulee') $$,
  'Délai 2 h : annulation du rendez-vous dans 3 h acceptée');

-- Retour à 0 par le gérant : le rendez-vous dans 1 h redevient annulable.
select pg_temp.connecter('00000a01-0000-0000-0000-000000000118');
select results_eq(
  $$ select delai_annulation_minutes from public.definir_delai_annulation(
       '0000000a-0000-0000-0000-000000000118', 0) $$,
  $$ values (0) $$,
  'Gérant de A : délai remis à 0');

select pg_temp.connecter('00000c1a-0000-0000-0000-000000000118');
select results_eq(
  $$ select annulable from public.mes_reservations('0000000a-0000-0000-0000-000000000118')
      where id = '000000d1-0000-0000-0000-000000000118' $$,
  $$ values (true) $$,
  'Délai 0 : le rendez-vous dans 1 h est annulable');

select lives_ok(
  $$ select * from public.annuler_reservation('000000d1-0000-0000-0000-000000000118') $$,
  'Délai 0 : annulation acceptée');

-- Le délai se lit publiquement (message du site).
reset role;
set local role anon;
select results_eq(
  $$ select delai_annulation_minutes from public.salons
      where id = '0000000a-0000-0000-0000-000000000118' $$,
  $$ values (0) $$,
  'anon lit le délai du salon');

select * from finish();
rollback;
