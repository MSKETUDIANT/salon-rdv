-- Issue #148 : compte créé par l'e-mail d'invitation, rôle coiffeur à la
-- confirmation de l'adresse (code saisi dans l'app), renvoi de l'invitation.
begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

-- Jeu de données : salon A, son gérant gA (confirmé).
insert into public.salons (id, nom) values
  ('0000000a-0000-0000-0000-000000000148', 'Salon A');

insert into auth.users (id, email, raw_user_meta_data, email_confirmed_at) values
  ('00000a01-0000-0000-0000-000000000148', 'ga@email.test', '{"nom":"Gérant A"}', now());

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000148';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000148', '0000000a-0000-0000-0000-000000000148', 'gerant');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

create function pg_temp.coiffeur(p_email text) returns boolean language sql as $$
  select exists (
    select 1 from public.roles_utilisateur r
      join public.utilisateurs u on u.id = r.utilisateur_id
     where lower(u.email) = lower(p_email) and r.role = 'coiffeur'
       and r.salon_id = '0000000a-0000-0000-0000-000000000148');
$$;

create function pg_temp.en_attente(p_email text) returns boolean language sql as $$
  select exists (
    select 1 from public.invitations
     where email = lower(p_email) and acceptee_le is null);
$$;

-- ------------------------------------------------------------
-- Invitation, puis compte créé par l'e-mail d'invitation (non confirmé)
-- ------------------------------------------------------------

set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000148');
select results_eq(
  $$ select * from public.inviter_coiffeur('0000000a-0000-0000-0000-000000000148', 'nour@email.test', 'Nour') $$,
  $$ values ('invite'::text) $$,
  'Pas de compte : invitation en attente');
reset role;

-- Ce que fait l'invitation de Supabase Auth : compte créé, adresse non
-- confirmée, nom dans les métadonnées.
insert into auth.users (id, email, raw_user_meta_data, invited_at) values
  ('00000e01-0000-0000-0000-000000000148', 'nour@email.test', '{"nom":"Nour"}', now());

select ok(not pg_temp.coiffeur('nour@email.test'),
  'Compte non confirmé : pas encore coiffeur');
select ok(pg_temp.en_attente('nour@email.test'),
  'Compte non confirmé : invitation toujours en attente');

-- Renvoyer : le compte non confirmé ne compte pas comme existant.
set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000148');
select results_eq(
  $$ select * from public.inviter_coiffeur('0000000a-0000-0000-0000-000000000148', 'Nour@email.test', 'Nour Ben') $$,
  $$ values ('invite'::text) $$,
  'Réinviter un compte non confirmé : invitation renvoyée, pas d''ajout');
select results_eq(
  $$ select count(*)::integer, max(nom) from public.invitations where email = 'nour@email.test' $$,
  $$ values (1, 'Nour Ben'::text) $$,
  'Toujours une seule invitation, nom mis à jour');
reset role;

-- ------------------------------------------------------------
-- Confirmation de l'adresse (code saisi dans l'app)
-- ------------------------------------------------------------

update auth.users set email_confirmed_at = now()
 where id = '00000e01-0000-0000-0000-000000000148';

select ok(pg_temp.coiffeur('nour@email.test'), 'Adresse confirmée : coiffeur du salon');
select ok(not pg_temp.en_attente('nour@email.test'), 'Invitation marquée acceptée');

-- Une autre mise à jour du compte ne refait rien.
update auth.users set email_confirmed_at = now(), last_sign_in_at = now()
 where id = '00000e01-0000-0000-0000-000000000148';
select is(
  (select count(*)::integer from public.roles_utilisateur
    where utilisateur_id = '00000e01-0000-0000-0000-000000000148' and role = 'coiffeur'),
  1, 'Reconnexion : pas de rôle en double');

-- Confirmé : réinviter dit « déjà dans l'équipe ».
set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000148');
select throws_ok(
  $$ select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000148', 'nour@email.test', 'Nour') $$,
  'PT409', 'Déjà dans l''équipe', 'Compte confirmé et coiffeur : déjà dans l''équipe');

-- ------------------------------------------------------------
-- Invitation annulée avant la confirmation
-- ------------------------------------------------------------

select public.inviter_coiffeur('0000000a-0000-0000-0000-000000000148', 'sami@email.test', 'Sami');
reset role;
insert into auth.users (id, email, raw_user_meta_data, invited_at) values
  ('00000e02-0000-0000-0000-000000000148', 'sami@email.test', '{"nom":"Sami"}', now());

set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000148');
select public.annuler_invitation(
  (select id from public.invitations where email = 'sami@email.test'));
reset role;

update auth.users set email_confirmed_at = now()
 where id = '00000e02-0000-0000-0000-000000000148';
select ok(not pg_temp.coiffeur('sami@email.test'),
  'Invitation annulée puis adresse confirmée : pas coiffeur');

-- ------------------------------------------------------------
-- Adresse confirmée sans invitation (client du site)
-- ------------------------------------------------------------

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000e03-0000-0000-0000-000000000148', 'client@email.test', '{"nom":"Client"}');
update auth.users set email_confirmed_at = now()
 where id = '00000e03-0000-0000-0000-000000000148';
select ok(not pg_temp.coiffeur('client@email.test'),
  'Client qui confirme son adresse : pas coiffeur');

-- Fonction interne : pas appelable par les comptes.
select ok(
  not has_function_privilege('authenticated', 'private.accepter_invitations(uuid, text)', 'execute'),
  'accepter_invitations() réservée aux déclencheurs');

select * from finish();
rollback;
