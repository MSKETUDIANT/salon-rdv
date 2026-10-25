-- Issue #3 : RLS de reservations et trigger des transitions de statut.
begin;

create extension if not exists pgtap with schema extensions;

select plan(29);

-- ------------------------------------------------------------
-- Jeu de données commun aux tests RLS : salons A et B
-- (le seed ajoute un salon de démo, que personne ici ne doit voir non plus).
--   A : gérant a1, coiffeur a2, clients a3 et a4
--   B : gérant b1, coiffeur b2, client b3
-- ------------------------------------------------------------

insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000000', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000000', 'Salon B');

-- Le trigger on_auth_user_created crée la ligne utilisateurs et le rôle client.
insert into auth.users (id, email, raw_user_meta_data) values
  ('000000a1-0000-0000-0000-000000000000', 'gerant-a@rls.test',   '{"nom":"Gérant A","salon_id":"0000000a-0000-0000-0000-000000000000"}'),
  ('000000a2-0000-0000-0000-000000000000', 'coiffeur-a@rls.test', '{"nom":"Coiffeur A","salon_id":"0000000a-0000-0000-0000-000000000000"}'),
  ('000000a3-0000-0000-0000-000000000000', 'client-a@rls.test',   '{"nom":"Client A","salon_id":"0000000a-0000-0000-0000-000000000000"}'),
  ('000000a4-0000-0000-0000-000000000000', 'client2-a@rls.test',  '{"nom":"Client 2 A","salon_id":"0000000a-0000-0000-0000-000000000000"}'),
  ('000000b1-0000-0000-0000-000000000000', 'gerant-b@rls.test',   '{"nom":"Gérant B","salon_id":"0000000b-0000-0000-0000-000000000000"}'),
  ('000000b2-0000-0000-0000-000000000000', 'coiffeur-b@rls.test', '{"nom":"Coiffeur B","salon_id":"0000000b-0000-0000-0000-000000000000"}'),
  ('000000b3-0000-0000-0000-000000000000', 'client-b@rls.test',   '{"nom":"Client B","salon_id":"0000000b-0000-0000-0000-000000000000"}');

insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('000000a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', 'gerant'),
  ('000000a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', 'coiffeur'),
  ('000000b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', 'gerant'),
  ('000000b2-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', 'coiffeur');

-- Prestations : f0a1 et f0b1 actives, f0a2 et f0b2 inactives.
insert into public.prestations (id, salon_id, nom, prix, duree_minutes, active) values
  ('0000f0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', 'Coupe A',      20, 30, true),
  ('0000f0a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', 'Ancienne A',   15, 30, false),
  ('0000f0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', 'Coupe B',      20, 30, true),
  ('0000f0b2-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', 'Ancienne B',   15, 30, false);

insert into public.competences (coiffeur_id, prestation_id) values
  ('000000a2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000'),
  ('000000b2-0000-0000-0000-000000000000', '0000f0b1-0000-0000-0000-000000000000');

insert into public.horaires (id, salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('0000e0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', 1, '09:00', '18:00'),
  ('0000e0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000', 1, '09:00', '18:00');

insert into public.absences (id, salon_id, coiffeur_id, debut, fin, motif) values
  ('0000d0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '2026-11-09 09:00+00', '2026-11-09 18:00+00', 'Formation A'),
  ('0000d0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '2026-11-09 09:00+00', '2026-11-09 18:00+00', 'Formation B');

-- Réservations : c0a1 et c0a4 (client a3) et c0a2 (client a4) confirmées,
-- c0a3 (a3) terminée ; c0b1 confirmée et c0b2 terminée (client b3).
-- Depuis l'issue #6, un client ne crée plus de réservation lui-même : elles
-- passent par public.reserver() (tests dans reserver.test.sql).
insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('0000c0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-02 11:00+00', '2026-11-02 11:30+00', 'confirmee'),
  ('0000c0a3-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee'),
  ('0000c0a4-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-03 10:00+00', '2026-11-03 10:30+00', 'confirmee'),
  ('0000c0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0b2-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee');

insert into public.encaissements (id, reservation_id, montant, encaisse_par) values
  ('0000b0a1-0000-0000-0000-000000000000', '0000c0a3-0000-0000-0000-000000000000', 20, '000000a1-0000-0000-0000-000000000000'),
  ('0000b0b1-0000-0000-0000-000000000000', '0000c0b2-0000-0000-0000-000000000000', 30, '000000b1-0000-0000-0000-000000000000');

-- ------------------------------------------------------------
-- Client
-- ------------------------------------------------------------

-- Agit en tant que Client A (a3).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a3-0000-0000-0000-000000000000","role":"authenticated"}', true);

-- Critère d'acceptation : un client ne peut pas lire la réservation d'un autre client.
select is_empty(
  $$ select id from public.reservations where id = '0000c0a2-0000-0000-0000-000000000000' $$,
  'Client A : ne lit pas la réservation du client a4 (même salon)'
);

select results_eq(
  $$ select id from public.reservations order by id $$,
  $$ values ('0000c0a1-0000-0000-0000-000000000000'::uuid), ('0000c0a3-0000-0000-0000-000000000000'::uuid), ('0000c0a4-0000-0000-0000-000000000000'::uuid) $$,
  'Client A : ne voit que ses trois réservations'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00') $$,
  '42501',
  null,
  'Client A : insertion directe refusée, même pour lui (passe par reserver())'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00') $$,
  '42501',
  null,
  'Client A : réserver au nom d''un autre client refusé'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000b-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000', '0000f0b1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00') $$,
  '42501',
  null,
  'Client A : réserver dans B (pas client de B) refusé'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00') $$,
  '42501',
  null,
  'Client A : réserver dans A avec le coiffeur de B refusé'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '0000f0b1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00') $$,
  '42501',
  null,
  'Client A : réserver dans A une prestation de B refusé'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut)
     values ('0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000',
             '2026-11-03 14:00+00', '2026-11-03 14:30+00', 'terminee') $$,
  '42501',
  null,
  'Client A : créer une réservation déjà terminée refusé'
);

-- Depuis #7, le client annule par annuler_reservation() ; la modification
-- directe est sans effet (mes_reservations.test.sql).
select results_eq(
  $$ with m as (
       update public.reservations set statut = 'annulee' where id = '0000c0a1-0000-0000-0000-000000000000'
       returning 1)
     select count(*)::int from m $$,
  $$ values (0) $$,
  'Client A : annuler sa réservation par modification directe sans effet (0 ligne, #7)'
);

select results_eq(
  $$ select statut::text from public.annuler_reservation('0000c0a1-0000-0000-0000-000000000000') $$,
  $$ values ('annulee') $$,
  'Client A : annule sa réservation avec annuler_reservation()'
);

select results_eq(
  $$ with m as (
       update public.reservations set statut = 'terminee' where id = '0000c0a4-0000-0000-0000-000000000000'
       returning 1)
     select count(*)::int from m $$,
  $$ values (0) $$,
  'Client A : marquer sa réservation terminée sans effet (0 ligne)'
);

select throws_ok(
  $$ update public.reservations set debut = '2026-11-03 11:00+00' where id = '0000c0a4-0000-0000-0000-000000000000' $$,
  '42501',
  null,
  'Client A : modifier l''heure refusé (colonne)'
);

select lives_ok(
  $$ update public.reservations set statut = 'annulee' where id in ('0000c0a2-0000-0000-0000-000000000000', '0000c0b1-0000-0000-0000-000000000000') $$,
  'Client A : annuler la réservation d''un autre sans effet (0 ligne)'
);

select lives_ok(
  $$ delete from public.reservations where id = '0000c0a4-0000-0000-0000-000000000000' $$,
  'Client A : suppression sans effet (pas de policy DELETE)'
);

-- Agit en tant que Client B (b3).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000b3-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is_empty(
  $$ select id from public.reservations where salon_id = '0000000a-0000-0000-0000-000000000000' $$,
  'Client B : ne voit aucune réservation de A'
);

-- ------------------------------------------------------------
-- Coiffeur
-- ------------------------------------------------------------

-- Agit en tant que Coiffeur A (a2).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a2-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.reservations order by id $$,
  $$ values ('0000c0a1-0000-0000-0000-000000000000'::uuid), ('0000c0a2-0000-0000-0000-000000000000'::uuid), ('0000c0a3-0000-0000-0000-000000000000'::uuid), ('0000c0a4-0000-0000-0000-000000000000'::uuid) $$,
  'Coiffeur A : voit ses quatre réservations, aucune de B'
);

select lives_ok(
  $$ update public.reservations set statut = 'terminee' where id = '0000c0a2-0000-0000-0000-000000000000' $$,
  'Coiffeur A : marque une réservation terminée'
);

select throws_ok(
  $$ update public.reservations set statut = 'annulee' where id = '0000c0a4-0000-0000-0000-000000000000' $$,
  '42501',
  null,
  'Coiffeur A : annuler une réservation refusé'
);

select lives_ok(
  $$ update public.reservations set statut = 'absent' where id = '0000c0b1-0000-0000-0000-000000000000' $$,
  'Coiffeur A : modifier une réservation de B sans effet (0 ligne)'
);

-- ------------------------------------------------------------
-- Gérant
-- ------------------------------------------------------------

-- Agit en tant que Gérant A (a1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is(
  (select count(*)::int from public.reservations where salon_id = '0000000a-0000-0000-0000-000000000000'),
  4,
  'Gérant A : voit les 4 réservations de A'
);

select is(
  (select count(*)::int from public.reservations where salon_id <> '0000000a-0000-0000-0000-000000000000'),
  0,
  'Gérant A : ne voit aucune réservation hors de A'
);

select lives_ok(
  $$ update public.reservations set statut = 'annulee' where id = '0000c0a4-0000-0000-0000-000000000000' $$,
  'Gérant A : annule une réservation de son salon'
);

select lives_ok(
  $$ update public.reservations set statut = 'annulee' where id = '0000c0b1-0000-0000-0000-000000000000' $$,
  'Gérant A : modifier une réservation de B sans effet (0 ligne)'
);

-- Trigger : transitions interdites, quel que soit le rôle.
select throws_ok(
  $$ update public.reservations set statut = 'confirmee' where id = '0000c0a3-0000-0000-0000-000000000000' $$,
  '23514',
  'Transition de statut interdite : terminee -> confirmee',
  'Gérant A : terminee -> confirmee refusé par le trigger'
);

select throws_ok(
  $$ update public.reservations set statut = 'terminee' where id = '0000c0a1-0000-0000-0000-000000000000' $$,
  '23514',
  'Transition de statut interdite : annulee -> terminee',
  'Gérant A : annulee -> terminee refusé par le trigger'
);

-- ------------------------------------------------------------
-- anon
-- ------------------------------------------------------------

-- Agit en tant que visiteur sans compte (anon).
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty(
  $$ select id from public.reservations $$,
  'anon : aucune réservation visible'
);

select throws_ok(
  $$ insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '0000f0a1-0000-0000-0000-000000000000',
             '2026-11-03 16:00+00', '2026-11-03 16:30+00') $$,
  '42501',
  null,
  'anon : création de réservation refusée'
);

-- Vérifications après coup, hors RLS.
reset role;

select results_eq(
  $$ select id, statut::text from public.reservations
      where salon_id in ('0000000a-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000') order by id $$,
  $$ values ('0000c0a1-0000-0000-0000-000000000000'::uuid, 'annulee'),
            ('0000c0a2-0000-0000-0000-000000000000'::uuid, 'terminee'),
            ('0000c0a3-0000-0000-0000-000000000000'::uuid, 'terminee'),
            ('0000c0a4-0000-0000-0000-000000000000'::uuid, 'annulee'),
            ('0000c0b1-0000-0000-0000-000000000000'::uuid, 'confirmee'),
            ('0000c0b2-0000-0000-0000-000000000000'::uuid, 'terminee') $$,
  'Statuts finaux : seuls les changements autorisés ont eu lieu'
);

select throws_ok(
  $$ update public.reservations set statut = 'annulee' where id = '0000c0b2-0000-0000-0000-000000000000' $$,
  '23514',
  'Transition de statut interdite : terminee -> annulee',
  'Hors API (postgres) : terminee -> annulee refusé aussi'
);

select * from finish();

rollback;
