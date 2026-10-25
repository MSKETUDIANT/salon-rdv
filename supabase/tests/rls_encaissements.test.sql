-- Issue #3 : RLS de encaissements (gérant du salon seulement, pas de DELETE).
begin;

create extension if not exists pgtap with schema extensions;

select plan(13);

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

-- Réservations : c0a1 (client a3) confirmée ; c0a2 (client a4) et c0a5 (a3),
-- passées sans encaissement, et c0a3 (a3) terminées ; c0b1 confirmée et c0b2 terminée
-- (client b3). Depuis #11, seul un rendez-vous terminé est encaissable.
insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('0000c0a1-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', now() - interval '30 days', now() - interval '30 days' + interval '30 minutes', 'terminee'),
  ('0000c0a5-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', now() - interval '31 days', now() - interval '31 days' + interval '30 minutes', 'terminee'),
  ('0000c0a3-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000',
   '0000f0a1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee'),
  ('0000c0b1-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-11-02 10:00+00', '2026-11-02 10:30+00', 'confirmee'),
  ('0000c0b2-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000',
   '0000f0b1-0000-0000-0000-000000000000', '2026-10-26 10:00+00', '2026-10-26 10:30+00', 'terminee');

insert into public.encaissements (id, reservation_id, montant, encaisse_par) values
  ('0000b0a1-0000-0000-0000-000000000000', '0000c0a3-0000-0000-0000-000000000000', 20, '000000a1-0000-0000-0000-000000000000'),
  ('0000b0b1-0000-0000-0000-000000000000', '0000c0b2-0000-0000-0000-000000000000', 30, '000000b1-0000-0000-0000-000000000000');

-- Agit en tant que Gérant A (a1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.encaissements $$,
  $$ values ('0000b0a1-0000-0000-0000-000000000000'::uuid) $$,
  'Gérant A : ne voit que l''encaissement de A'
);

select lives_ok(
  $$ insert into public.encaissements (id, reservation_id, montant, encaisse_par)
     values ('0000b0a2-0000-0000-0000-000000000000', '0000c0a2-0000-0000-0000-000000000000', 20, '000000a1-0000-0000-0000-000000000000') $$,
  'Gérant A : enregistre un encaissement dans A'
);

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('0000c0a5-0000-0000-0000-000000000000', 20, '000000a2-0000-0000-0000-000000000000') $$,
  '42501',
  null,
  'Gérant A : encaissement au nom d''un autre refusé'
);

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('0000c0b1-0000-0000-0000-000000000000', 20, '000000a1-0000-0000-0000-000000000000') $$,
  '42501',
  null,
  'Gérant A : encaissement sur une réservation de B refusé'
);

select lives_ok(
  $$ update public.encaissements set montant = 22 where id = '0000b0a1-0000-0000-0000-000000000000' $$,
  'Gérant A : modifie un encaissement de A'
);

select lives_ok(
  $$ update public.encaissements set montant = 0 where id = '0000b0b1-0000-0000-0000-000000000000' $$,
  'Gérant A : modification d''un encaissement de B sans effet (0 ligne)'
);

select lives_ok(
  $$ delete from public.encaissements where id = '0000b0a1-0000-0000-0000-000000000000' $$,
  'Gérant A : suppression sans effet (pas de policy DELETE)'
);

-- Agit en tant que Gérant B (b1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000b1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.encaissements $$,
  $$ values ('0000b0b1-0000-0000-0000-000000000000'::uuid) $$,
  'Gérant B : ne voit que l''encaissement de B'
);

-- Agit en tant que Coiffeur A (a2).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a2-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is_empty(
  $$ select id from public.encaissements $$,
  'Coiffeur A : aucun encaissement visible'
);

select throws_ok(
  $$ insert into public.encaissements (reservation_id, montant, encaisse_par)
     values ('0000c0a5-0000-0000-0000-000000000000', 20, '000000a2-0000-0000-0000-000000000000') $$,
  '42501',
  null,
  'Coiffeur A : enregistrer un encaissement refusé'
);

-- Agit en tant que Client A (a3).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a3-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is_empty(
  $$ select id from public.encaissements $$,
  'Client A : aucun encaissement visible, même sur sa réservation'
);

-- Agit en tant que visiteur sans compte (anon).
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty(
  $$ select id from public.encaissements $$,
  'anon : aucun encaissement visible'
);

-- Vérifications après coup, hors RLS.
reset role;

select results_eq(
  $$ select id, montant from public.encaissements
      where reservation_id::text like '0000c0%' order by id $$,
  $$ values ('0000b0a1-0000-0000-0000-000000000000'::uuid, 22.000), ('0000b0a2-0000-0000-0000-000000000000'::uuid, 20.000), ('0000b0b1-0000-0000-0000-000000000000'::uuid, 30.000) $$,
  'Encaissements : A modifié et ajouté, B intact, rien de supprimé'
);

select * from finish();

rollback;
