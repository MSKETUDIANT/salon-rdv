-- Issue #6 : réserver un créneau (BF-C5), revérification de la disponibilité,
-- zéro double réservation (BNF-1).
begin;

create extension if not exists pgtap with schema extensions;

select plan(23);

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
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
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

-- 1. Un visiteur sans compte ne peut pas réserver.
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  '42501', null, 'Visiteur sans compte : réservation refusée');

reset role;
set local role authenticated;

-- 2. Connecté sans identifiant : refusé avec PT401.
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  'PT401', 'Connexion requise pour réserver', 'Sans identifiant : PT401');

-- 3. Client 1 réserve A à 9h : la réservation est la sienne, 9h-9h30, confirmée.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');
select results_eq(
  $$ select coiffeur_id, debut, fin from public.reserver(
       '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1'::uuid,
             '2030-01-07 09:00+01'::timestamptz, '2030-01-07 09:30+01'::timestamptz) $$,
  'Client 1 : réserve A à 9h (9h-9h30)');

select results_eq(
  $$ select client_id, statut::text from public.reservations
      where coiffeur_id = '00000000-0000-0000-0000-0000000000a1' and debut = '2030-01-07 09:00+01' $$,
  $$ values ('00000000-0000-0000-0000-0000000000c1'::uuid, 'confirmee') $$,
  'BF-C5 : réservation enregistrée, rattachée au client connecté, confirmée');

-- 4. Le même créneau avec le même coiffeur : refusé (PT409).
select pg_temp.connecter('00000000-0000-0000-0000-0000000000c2');
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', 'Ce créneau n''est plus disponible', 'Créneau déjà pris chez A : PT409');

-- 5. Chevauchement partiel (9h15) chez A : refusé.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:15+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', null, 'Chevauchement partiel chez A : PT409');

-- 6. « Peu importe » à 9h : A est pris, B est attribué.
select results_eq(
  $$ select coiffeur_id from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  $$ values ('00000000-0000-0000-0000-0000000000b1'::uuid) $$,
  '« Peu importe » : A pris à 9h, B attribué');

-- 7. « Peu importe » à 9h une troisième fois : plus personne (C n'est pas compétent).
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01') $$,
  'PT409', null, '« Peu importe » : A et B pris, C non compétent : PT409');

-- 8. « Peu importe » attribue le coiffeur le moins chargé ce jour-là : à 10h,
--    A et B ont chacun une réservation (9h) ; on charge A d'une deuxième.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:30+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'Client 1 : réserve aussi A à 9h30');
select results_eq(
  $$ select coiffeur_id from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:00+01') $$,
  $$ values ('00000000-0000-0000-0000-0000000000b1'::uuid) $$,
  '« Peu importe » à 10h : B (1 réservation) avant A (2)');

-- 9. Coiffeur non compétent demandé explicitement : refusé.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:30+01',
       '00000000-0000-0000-0000-0000000000c3') $$,
  'PT409', null, 'Coiffeur C non compétent : PT409');

-- 10. Hors horaires (13h) : refusé.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 13:00+01') $$,
  'PT409', null, 'Hors horaires (13h) : PT409');

-- 11. Pendant l'absence de A (11h) : refusé chez A...
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 11:00+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', null, 'Pendant l''absence de A : PT409');

-- 12. ... et « Peu importe » à 11h attribue B.
select results_eq(
  $$ select coiffeur_id from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 11:00+01') $$,
  $$ values ('00000000-0000-0000-0000-0000000000b1'::uuid) $$,
  '« Peu importe » pendant l''absence de A : B attribué');

-- 13. Heure qui n'est pas un début de créneau (10h35) : refusé.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:35+01',
       '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', null, 'Heure hors pas des créneaux (10h35) : PT409');

-- 14. Dans le passé : refusé.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1',
       date_trunc('hour', now()) - interval '1 day') $$,
  'PT409', null, 'Créneau passé : PT409');

-- 15. Prestation inactive : PT404.
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e2', '2030-01-07 10:30+01') $$,
  'PT404', 'Prestation introuvable', 'Prestation inactive : PT404');

-- 16. Compte sans rôle client dans ce salon : PT403.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000f0');
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:30+01') $$,
  'PT403', null, 'Compte non client du salon : PT403');

-- 17. Plus d'insertion directe, même pour soi et sur un créneau libre.
select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
             '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1',
             '2030-01-07 10:30+01', '2030-01-07 11:00+01') $$,
  '42501', null, 'Insertion directe refusée : reserver() est le seul chemin');

-- 18. Le client ne lit que ses réservations (4 pour client 1 : 9h, 9h30, 10h,
--     11h ; client 2 a celle de B à 9h).
select is((select count(*) from public.reservations), 4::bigint,
  'Client 1 : lit ses 4 réservations, pas celle de client 2');

-- 19. BNF-1 : jamais deux réservations non annulées qui se chevauchent pour un
--     coiffeur (contrôle sur toutes les réservations du jeu de données).
reset role;
select is((
  select count(*) from public.reservations r1
    join public.reservations r2
      on r1.coiffeur_id = r2.coiffeur_id and r1.id < r2.id
     and r1.statut <> 'annulee' and r2.statut <> 'annulee'
     and tstzrange(r1.debut, r1.fin, '[)') && tstzrange(r2.debut, r2.fin, '[)')
   where r1.salon_id = '00000000-0000-0000-0000-000000000001'
  ), 0::bigint, 'BNF-1 : aucune paire de réservations qui se chevauchent');

-- 20. Le droit d'exécuter est réservé aux comptes connectés.
select ok(
  has_function_privilege('authenticated', 'public.reserver(uuid, timestamptz, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.reserver(uuid, timestamptz, uuid)', 'execute'),
  'reserver() : exécutable par authenticated, pas par anon');

-- 21. security definer, search_path vide.
select is(
  (select prosecdef and proconfig @> array['search_path=""']
     from pg_proc where oid = 'public.reserver(uuid, timestamptz, uuid)'::regprocedure),
  true, 'reserver() : security definer, search_path fixé à vide');

select * from finish();
rollback;
