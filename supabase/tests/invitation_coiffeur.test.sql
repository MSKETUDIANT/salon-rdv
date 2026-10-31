-- Issue #145 : invitation d'un coiffeur par le gérant (invitations,
-- inviter_coiffeur, annuler_invitation, déclencheur d'inscription).
begin;

create extension if not exists pgtap with schema extensions;

select plan(25);

-- Jeu de données : salons A et B.
--   gA : gérant de A ; c1 : coiffeur de A ; gB : gérant de B ;
--   cl : compte existant, client de A seulement.
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000145', 'Salon A'),
  ('0000000b-0000-0000-0000-000000000145', 'Salon B');

-- Comptes confirmés (#148 : un compte non confirmé reste une invitation).
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('00000a01-0000-0000-0000-000000000145', 'ga@invit.test', '{"nom":"Gérant A"}', now()),
  ('00000c01-0000-0000-0000-000000000145', 'c1@invit.test', '{"nom":"Coiffeur 1"}', now()),
  ('00000b01-0000-0000-0000-000000000145', 'gb@invit.test', '{"nom":"Gérant B"}', now()),
  ('00000c1a-0000-0000-0000-000000000145', 'client@invit.test', '{"nom":"Salma"}', now());

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000145';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000145', '0000000a-0000-0000-0000-000000000145', 'gerant'),
  ('00000c01-0000-0000-0000-000000000145', '0000000a-0000-0000-0000-000000000145', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000145', '0000000b-0000-0000-0000-000000000145', 'gerant'),
  ('00000c1a-0000-0000-0000-000000000145', '0000000a-0000-0000-0000-000000000145', 'client');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.roles(p_email text) returns text[] language sql as $$
  select coalesce(array_agg(r.role::text || '@' || s.nom order by s.nom, r.role), '{}')
    from public.roles_utilisateur r
    join public.utilisateurs u on u.id = r.utilisateur_id
    join public.salons s on s.id = r.salon_id
   where u.email = p_email;
$$;

-- ------------------------------------------------------------
-- Droits
-- ------------------------------------------------------------

set local role anon;
select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nouveau@invit.test', 'Nour') $$,
  '42501', null, 'Sans compte : pas le droit d''inviter');

set local role authenticated;
select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nouveau@invit.test', 'Nour') $$,
  'PT401', null, 'Connecté sans identité : refusé');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000145');
select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nouveau@invit.test', 'Nour') $$,
  'PT403', null, 'Un coiffeur n''invite pas');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000145');
select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nouveau@invit.test', 'Nour') $$,
  'PT403', null, 'Le gérant d''un autre salon n''invite pas');

-- ------------------------------------------------------------
-- Saisie
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000145');

select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'pas-un-email', 'Nour') $$,
  'PT400', 'Adresse e-mail invalide', 'E-mail invalide : message clair');

select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nouveau@invit.test', '   ') $$,
  'PT400', 'Nom invalide', 'Nom vide : message clair');

-- ------------------------------------------------------------
-- Invitation en attente
-- ------------------------------------------------------------

select results_eq(
  $$ select * from public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', '  Nour.Ben@Invit.TEST ', ' Nour  Ben ') $$,
  $$ values ('invite'::text) $$,
  'Pas de compte : invitation en attente');

select results_eq(
  $$ select email, nom from public.invitations where salon_id = '0000000a-0000-0000-0000-000000000145' $$,
  $$ values ('nour.ben@invit.test'::text, 'Nour Ben'::text) $$,
  'E-mail en minuscules sans espaces, nom nettoyé ; le gérant la lit');

select results_eq(
  $$ select * from public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'nour.ben@invit.test', 'Nour Ben Salah') $$,
  $$ values ('invite'::text) $$,
  'Réinviter la même adresse : pas de doublon');

select results_eq(
  $$ select count(*)::integer, max(nom) from public.invitations where email = 'nour.ben@invit.test' $$,
  $$ values (1, 'Nour Ben Salah'::text) $$,
  'Une seule invitation, nom mis à jour');

-- Lecture réservée au gérant du salon.
select pg_temp.connecter('00000c01-0000-0000-0000-000000000145');
select is_empty($$ select * from public.invitations $$, 'Un coiffeur ne lit pas les invitations');
select pg_temp.connecter('00000b01-0000-0000-0000-000000000145');
select is_empty($$ select * from public.invitations $$, 'Le gérant d''un autre salon ne les lit pas');

-- Pas d'écriture directe.
select pg_temp.connecter('00000a01-0000-0000-0000-000000000145');
select throws_ok(
  $$ insert into public.invitations (salon_id, email, nom)
     values ('0000000a-0000-0000-0000-000000000145', 'direct@invit.test', 'Direct') $$,
  '42501', null, 'Le gérant n''écrit pas directement dans invitations');

-- ------------------------------------------------------------
-- Compte existant
-- ------------------------------------------------------------

select results_eq(
  $$ select * from public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'CLIENT@invit.test', 'Salma') $$,
  $$ values ('ajoute'::text) $$,
  'Compte existant : rôle coiffeur donné tout de suite');

select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'c1@invit.test', 'Coiffeur 1') $$,
  'PT409', 'Déjà dans l''équipe', 'Déjà coiffeur : message clair');

reset role;
select is(pg_temp.roles('client@invit.test'), array['client@Salon A', 'coiffeur@Salon A'],
  'Le client garde son rôle client et devient coiffeur');
select is_empty(
  $$ select * from public.invitations where email = 'client@invit.test' $$,
  'Compte existant : aucune invitation laissée en attente');

-- ------------------------------------------------------------
-- Inscription d'un invité
-- ------------------------------------------------------------

-- E-mail en majuscules à l'inscription, sans nom : la casse ne compte pas,
-- le nom saisi par le gérant sert.
-- Compte créé déjà confirmé (#148 : sinon l'invitation attend la confirmation).
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('00000e01-0000-0000-0000-000000000145', 'Nour.Ben@invit.test', '{}', now());

-- Plusieurs salons dans la base de test : pas de rôle client automatique.
select is(pg_temp.roles('Nour.Ben@invit.test'), array['coiffeur@Salon A'],
  'Invité inscrit : rôle coiffeur dans le salon qui l''a invité');
select is(
  (select nom from public.utilisateurs where id = '00000e01-0000-0000-0000-000000000145'),
  'Nour Ben Salah', 'Sans nom à l''inscription : le nom saisi par le gérant');
select isnt(
  (select acceptee_le from public.invitations where email = 'nour.ben@invit.test'),
  null, 'Invitation marquée acceptée');

-- Un compte sans invitation ne devient pas coiffeur.
insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('00000e02-0000-0000-0000-000000000145', 'inconnu@invit.test', '{"nom":"Inconnu"}', now());
select is(pg_temp.roles('inconnu@invit.test'), '{}'::text[],
  'Inscription sans invitation : aucun rôle coiffeur');

-- ------------------------------------------------------------
-- Annulation
-- ------------------------------------------------------------

set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000145');
select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000145', 'annule@invit.test', 'À annuler');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000145');
select throws_ok(
  format('select public.annuler_invitation(%L)',
         (select id from public.invitations where email = 'annule@invit.test')),
  'PT404', null, 'Le gérant d''un autre salon n''annule pas');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000145');
select lives_ok(
  format('select public.annuler_invitation(%L)',
         (select id from public.invitations where email = 'annule@invit.test')),
  'Le gérant annule une invitation en attente');
select is_empty(
  $$ select * from public.invitations where email = 'annule@invit.test' $$,
  'Invitation annulée : retirée');

select throws_ok(
  format('select public.annuler_invitation(%L)',
         (select id from public.invitations where email = 'nour.ben@invit.test')),
  'PT404', null, 'Une invitation déjà acceptée ne s''annule pas');

select * from finish();
rollback;
