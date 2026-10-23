-- Issue #3 : RLS de utilisateurs et fonction coiffeurs_du_salon.
begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

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

-- ------------------------------------------------------------
-- anon : aucun droit sur utilisateurs, même par colonne
-- ------------------------------------------------------------

select is(
  (select count(*)::int from information_schema.role_column_grants
    where table_schema = 'public' and table_name = 'utilisateurs' and grantee = 'anon'),
  0,
  'anon : aucun droit sur utilisateurs, ni table ni colonne'
);

-- Agit en tant que visiteur sans compte (anon).
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select id from public.utilisateurs $$,
  '42501',
  null,
  'anon : lecture de utilisateurs refusée (même id)'
);

select throws_ok(
  $$ select nom from public.utilisateurs $$,
  '42501',
  null,
  'anon : lecture des noms refusée'
);

-- ------------------------------------------------------------
-- coiffeurs_du_salon : seulement (id, nom), seulement le salon demandé
-- ------------------------------------------------------------

select results_eq(
  $$ select id, nom::text from public.coiffeurs_du_salon('0000000a-0000-0000-0000-000000000000') $$,
  $$ values ('000000a2-0000-0000-0000-000000000000'::uuid, 'Coiffeur A') $$,
  'anon : coiffeurs_du_salon(A) ne renvoie que le coiffeur de A'
);

select is_empty(
  $$ select id from public.coiffeurs_du_salon('00000000-0000-0000-0000-00000000dead') $$,
  'coiffeurs_du_salon : salon inconnu, aucun résultat'
);

-- Agit en tant que Client A (a3).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a3-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id, nom::text from public.coiffeurs_du_salon('0000000b-0000-0000-0000-000000000000') $$,
  $$ values ('000000b2-0000-0000-0000-000000000000'::uuid, 'Coiffeur B') $$,
  'Client A : coiffeurs_du_salon(B) ne renvoie que le coiffeur de B'
);

select is(
  (select array_to_string(proargnames, ', ') from pg_proc
    where oid = 'public.coiffeurs_du_salon(uuid)'::regprocedure),
  'p_salon, id, nom',
  'coiffeurs_du_salon : ne renvoie que les colonnes id et nom'
);

-- ------------------------------------------------------------
-- Client
-- ------------------------------------------------------------

select results_eq(
  $$ select email::text from public.utilisateurs where id = '000000a3-0000-0000-0000-000000000000' $$,
  $$ values ('client-a@rls.test') $$,
  'Client A : lit sa ligne'
);

select is_empty(
  $$ select email, telephone from public.utilisateurs where id = '000000b2-0000-0000-0000-000000000000' $$,
  'Client A : ne lit ni l''e-mail ni le téléphone du coiffeur de B'
);

select is_empty(
  $$ select id from public.utilisateurs where id in ('000000a4-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000a1-0000-0000-0000-000000000000', '000000b1-0000-0000-0000-000000000000') $$,
  'Client A : ne voit ni les autres clients ni les gérants'
);

select lives_ok(
  $$ update public.utilisateurs set nom = 'Client A modifié' where id = '000000a3-0000-0000-0000-000000000000' $$,
  'Client A : modifie son nom'
);

select throws_ok(
  $$ update public.utilisateurs set email = 'autre@rls.test' where id = '000000a3-0000-0000-0000-000000000000' $$,
  '42501',
  null,
  'Client A : modification de son e-mail refusée (colonne)'
);

select lives_ok(
  $$ update public.utilisateurs set nom = 'Piraté' where id in ('000000a4-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000') $$,
  'Client A : modification d''autres utilisateurs sans effet (0 ligne)'
);

-- ------------------------------------------------------------
-- Coiffeur : les clients de ses réservations
-- ------------------------------------------------------------

-- Agit en tant que Coiffeur A (a2).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a2-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.utilisateurs where id in ('000000a3-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000') order by id $$,
  $$ values ('000000a3-0000-0000-0000-000000000000'::uuid), ('000000a4-0000-0000-0000-000000000000'::uuid) $$,
  'Coiffeur A : voit ses clients a3 et a4, pas le client de B'
);

-- ------------------------------------------------------------
-- Gérant : les membres de son salon
-- ------------------------------------------------------------

-- Agit en tant que Gérant A (a1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select results_eq(
  $$ select id from public.utilisateurs where id in ('000000a1-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000') order by id $$,
  $$ values ('000000a1-0000-0000-0000-000000000000'::uuid), ('000000a2-0000-0000-0000-000000000000'::uuid), ('000000a3-0000-0000-0000-000000000000'::uuid), ('000000a4-0000-0000-0000-000000000000'::uuid) $$,
  'Gérant A : voit les membres du salon A'
);

select is_empty(
  $$ select id from public.utilisateurs where id in ('000000b1-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000') $$,
  'Gérant A : ne voit aucun membre de B'
);

-- Agit en tant que Gérant B (b1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000b1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is_empty(
  $$ select id from public.utilisateurs where id in ('000000a1-0000-0000-0000-000000000000', '000000a2-0000-0000-0000-000000000000', '000000a3-0000-0000-0000-000000000000', '000000a4-0000-0000-0000-000000000000') $$,
  'Gérant B : ne voit aucun membre de A'
);

-- Vérifications après coup, hors RLS.
reset role;

select is(
  (select nom::text from public.utilisateurs where id = '000000a3-0000-0000-0000-000000000000'),
  'Client A modifié',
  'Le nom du client A a bien changé'
);

select results_eq(
  $$ select nom::text from public.utilisateurs where id in ('000000a4-0000-0000-0000-000000000000', '000000b3-0000-0000-0000-000000000000', '000000b2-0000-0000-0000-000000000000') order by nom $$,
  $$ values ('Client 2 A'), ('Client B'), ('Coiffeur B') $$,
  'Les autres utilisateurs sont intacts'
);

select * from finish();

rollback;
