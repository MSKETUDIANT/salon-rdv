-- Issue #3 : socle RLS (RLS active partout, liste exacte des policies, droits sur private.*).
begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

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
-- RLS et policies
-- ------------------------------------------------------------

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
  0,
  'RLS active sur toutes les tables de public'
);

select policies_are('public', 'salons', array[
  'salons : lecture publique'
], 'salons : liste exacte des policies');

select policies_are('public', 'utilisateurs', array[
  'utilisateurs : lecture de sa ligne',
  'utilisateurs : coiffeur lit ses clients',
  'utilisateurs : gérant lit les membres de son salon',
  'utilisateurs : modification de sa ligne'
], 'utilisateurs : liste exacte des policies');

select policies_are('public', 'roles_utilisateur', array[
  'roles : lecture de ses rôles',
  'roles : gérant lit les rôles de son salon'
], 'roles_utilisateur : liste exacte des policies (aucune écriture)');

select policies_are('public', 'prestations', array[
  'prestations : anon lit les actives',
  'prestations : lecture des actives, gérant lit tout son salon',
  'prestations : gérant crée',
  'prestations : gérant modifie'
], 'prestations : liste exacte des policies (pas de DELETE)');

select policies_are('public', 'competences', array[
  'competences : lecture publique',
  'competences : gérant ajoute',
  'competences : gérant retire'
], 'competences : liste exacte des policies');

select policies_are('public', 'horaires', array[
  'horaires : lecture par les comptes du salon',
  'horaires : gérant crée',
  'horaires : gérant modifie',
  'horaires : gérant supprime'
], 'horaires : liste exacte des policies');

select policies_are('public', 'absences', array[
  'absences : coiffeur lit les siennes',
  'absences : gérant lit son salon',
  'absences : gérant crée',
  'absences : gérant modifie',
  'absences : gérant supprime'
], 'absences : liste exacte des policies');

select policies_are('public', 'reservations', array[
  'reservations : client lit les siennes',
  'reservations : coiffeur lit les siennes',
  'reservations : gérant lit son salon',
  'reservations : coiffeur modifie les siennes',
  'reservations : gérant modifie son salon'
], 'reservations : liste exacte des policies (client : ni INSERT depuis #6, ni UPDATE depuis #7 ; pas de DELETE)');

select policies_are('public', 'encaissements', array[
  'encaissements : gérant lit son salon',
  'encaissements : gérant enregistre',
  'encaissements : gérant modifie'
], 'encaissements : liste exacte des policies (pas de DELETE)');

-- ------------------------------------------------------------
-- Droits d'exécution sur les fonctions private.*
-- ------------------------------------------------------------

-- Agit en tant que visiteur sans compte (anon).
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select private.a_le_role('0000000a-0000-0000-0000-000000000000', 'gerant') $$,
  '42501',
  null,
  'anon : exécution de private.a_le_role refusée'
);

select throws_ok(
  $$ select private.est_coiffeur_du_salon('000000a2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000') $$,
  '42501',
  null,
  'anon : exécution de private.est_coiffeur_du_salon refusée'
);

-- Agit en tant que Gérant A (a1).
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"000000a1-0000-0000-0000-000000000000","role":"authenticated"}', true);

select is(
  private.a_le_role('0000000a-0000-0000-0000-000000000000', 'gerant'),
  true,
  'authenticated : a_le_role exécutable (gérant A est gérant de A)'
);

select is(
  private.a_le_role('0000000b-0000-0000-0000-000000000000', 'gerant'),
  false,
  'a_le_role : gérant A n''est pas gérant de B'
);

select is(
  private.est_coiffeur_du_salon('000000b2-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000000'),
  false,
  'est_coiffeur_du_salon : coiffeur B n''est pas coiffeur de A'
);

select * from finish();

rollback;
