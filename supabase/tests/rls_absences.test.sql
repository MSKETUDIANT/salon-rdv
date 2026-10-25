-- Issue #3 : RLS de absences (coiffeur lit les siennes, gérant gère son salon, rien pour anon et client).
begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

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

-- Réservations : c0a1 (client a3) et c0a2 (client a4) confirmées, c0a3 (a3)
-- terminée ; c0b1 confirmée et c0b2 terminée (client b3).
insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('0000c0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-02 11:00+00', '2026-11-02 11:30+00', 'confirmee'),
  ('0000c0a3-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee'),
  ('0000c0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0b2-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee');

insert into public.encaissements (id, reservation_id, montant, encaisse_par) values
  ('0000b0a1-0000-0000-0000-000000000000', '0000c0a3-0000-0000-0000-000000000000', 20, '000000a1-0000-0000-0000-000000000000'),
  ('0000b0b1-0000-0000-0000-000000000000', '0000c0b2-0000-0000-0000-000000000000', 30, '000000b1-0000-0000-0000-000000000000');

-- Agit en tant que visiteur sans compte (anon).
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select id from public.absences $$,
  '42501',
  null,
  'anon : aucune absence lisible (droit de lecture retiré en #9)'
);

-- Agit en tant que Client A (a3).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a3-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is_empty(
  $$ select id from public.absences $$,
  'Client A : aucune absence visible'
);

-- Agit en tant que Coiffeur A (a2).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a2-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.absences $$,
  $$ values ('0000d0a1-0000-0000-0000-000000000000'::uuid) $$,
  'Coiffeur A : ne voit que son absence'
);

select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '2026-11-10 09:00+00', '2026-11-10 18:00+00') $$,
  '42501',
  null,
  'Coiffeur A : déclarer une absence lui-même refusé'
);

-- Agit en tant que Gérant A (a1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.absences where salon_id in ('0000000a-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000') $$,
  $$ values ('0000d0a1-0000-0000-0000-000000000000'::uuid) $$,
  'Gérant A : voit l''absence de A, pas celle de B'
);

select lives_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '2026-11-10 09:00+00', '2026-11-10 18:00+00') $$,
  'Gérant A : crée une absence pour le coiffeur A'
);

select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000b-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000', '2026-11-10 09:00+00', '2026-11-10 18:00+00') $$,
  '42501',
  null,
  'Gérant A : création d''absence dans B refusée'
);

select lives_ok(
  $$ update public.absences set motif = 'Congé' where id = '0000d0a1-0000-0000-0000-000000000000' $$,
  'Gérant A : modifie une absence de A'
);

select lives_ok(
  $$ update public.absences set motif = 'Piraté' where id = '0000d0b1-0000-0000-0000-000000000000' $$,
  'Gérant A : modification d''une absence de B sans effet (0 ligne)'
);

select lives_ok(
  $$ delete from public.absences where id = '0000d0b1-0000-0000-0000-000000000000' $$,
  'Gérant A : suppression d''une absence de B sans effet (0 ligne)'
);

-- Vérifications après coup, hors RLS.
reset role;

select is(
  (select motif::text from public.absences where id = '0000d0a1-0000-0000-0000-000000000000'),
  'Congé',
  'Absence A : modifiée par le gérant'
);

select is(
  (select motif::text from public.absences where id = '0000d0b1-0000-0000-0000-000000000000'),
  'Formation B',
  'Absence B : intacte'
);

select * from finish();

rollback;
