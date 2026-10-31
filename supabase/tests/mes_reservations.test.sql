-- Issue #7 : consulter et annuler sa réservation (BF-C6), un client ne voit
-- et n'annule que les siennes (BNF-3).
begin;

create extension if not exists pgtap with schema extensions;

select plan(33);

-- Jeu de données : salon 1 à Tunis (UTC+1), salon 2.
--   A : coiffeur du salon 1, lundi 9h-12h, sait faire Coupe (30 min).
--   Clients c1 et c2. Ancienne : prestation désactivée depuis.
--   Réservations de c1 dans le salon 1 :
--     r1 lundi 7 janvier 2030 9h, confirmée (à venir)
--     r2 6 janvier 2020, confirmée mais passée (jamais clôturée)
--     r3 13 janvier 2020, terminée
--     r4 lundi 7 janvier 2030 10h, annulée
--     r5 lundi 7 janvier 2030 11h, Ancienne, confirmée
--   r6 : c2, lundi 7 janvier 2030 9h30, confirmée.
--   r7 : c1 dans le salon 2.
insert into public.salons (id, nom, fuseau_horaire) values
  ('00000000-0000-0000-0000-000000000001', 'Salon 1', 'Africa/Tunis'),
  ('00000000-0000-0000-0000-000000000002', 'Salon 2', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000a1', 'a@mes.test',  '{"nom":"Coiffeur A"}'),
  ('00000000-0000-0000-0000-0000000000c1', 'c1@mes.test', '{"nom":"Client 1"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@mes.test', '{"nom":"Client 2"}');

-- Le trigger n'attribue le rôle client que s'il n'existe qu'un salon : rôles
-- posés ici.
delete from public.roles_utilisateur
 where utilisateur_id::text like '00000000-0000-0000-0000-0000000000%';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000002', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'client'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000002', 'client'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000001', 'client');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes, active) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000001', 'Coupe',    20,     30, true),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000001', 'Ancienne', 12.500, 30, false),
  ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-000000000002', 'Coupe 2',  25,     30, true);

insert into public.competences (coiffeur_id, prestation_id) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1');

insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 1, '09:00', '12:00');

insert into public.reservations (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:00+01', '2030-01-07 09:30+01', 'confirmee'),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', '2020-01-06 09:00+01', '2020-01-06 09:30+01', 'confirmee'),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', '2020-01-13 09:00+01', '2020-01-13 09:30+01', 'terminee'),
  ('00000000-0000-0000-0000-0000000000f4', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', '2030-01-07 10:00+01', '2030-01-07 10:30+01', 'annulee'),
  ('00000000-0000-0000-0000-0000000000f5', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e2', '2030-01-07 11:00+01', '2030-01-07 11:30+01', 'confirmee'),
  ('00000000-0000-0000-0000-0000000000f6', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c2',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', '2030-01-07 09:30+01', '2030-01-07 10:00+01', 'confirmee'),
  ('00000000-0000-0000-0000-0000000000f7', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e3', '2030-01-08 09:00+01', '2030-01-08 09:30+01', 'confirmee');

-- Se connecter comme un utilisateur donné.
create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Créneaux libres de A le lundi 7 janvier 2030 à 9h (0 ou 1).
create function pg_temp.creneau_9h_libre() returns bigint language sql as $$
  select count(*) from public.creneaux_disponibles(
    '00000000-0000-0000-0000-0000000000e1', '2030-01-07', '2030-01-07',
    '00000000-0000-0000-0000-0000000000a1')
   where debut = '2030-01-07 09:00+01';
$$;

-- ------------------------------------------------------------
-- Structure
-- ------------------------------------------------------------

select is(
  (select count(*)::int from pg_policies
    where tablename = 'reservations' and policyname = 'reservations : client modifie les siennes'),
  0, 'La policy de modification directe par le client est supprimée');

select is(
  (select bool_and(p.prosecdef and p.proconfig @> array['search_path=""'])
     from pg_proc p
    where p.oid in ('public.mes_reservations(uuid)'::regprocedure,
                    'public.annuler_reservation(uuid)'::regprocedure)),
  true, 'Les deux fonctions : security definer, search_path fixé');

select is(
  pg_get_function_arguments('public.annuler_reservation(uuid)'::regprocedure),
  'p_reservation uuid',
  'annuler_reservation : aucun paramètre client (le client vient de auth.uid())');

select ok(
  not has_function_privilege('anon', 'public.mes_reservations(uuid)', 'execute')
  and not has_function_privilege('anon', 'public.annuler_reservation(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.mes_reservations(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.annuler_reservation(uuid)', 'execute')
  and not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
     where p.oid in ('public.mes_reservations(uuid)'::regprocedure,
                     'public.annuler_reservation(uuid)'::regprocedure)
       and a.grantee = 0),
  'Exécution : authenticated seulement (ni public ni anon)');

-- ------------------------------------------------------------
-- Sans compte
-- ------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok(
  $$ select * from public.mes_reservations('00000000-0000-0000-0000-000000000001') $$,
  '42501', null, 'Visiteur sans compte : lecture refusée');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f1') $$,
  '42501', null, 'Visiteur sans compte : annulation refusée');

reset role;
set local role authenticated;

select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(
  (select count(*)::int from public.mes_reservations('00000000-0000-0000-0000-000000000001')),
  0, 'Connecté sans identifiant : aucune réservation');
select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f1') $$,
  'PT401', 'Connexion requise pour annuler', 'Sans identifiant : PT401');

-- ------------------------------------------------------------
-- Consulter (BF-C6, BNF-3)
-- ------------------------------------------------------------

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');

select results_eq(
  $$ select id, statut::text, annulable
       from public.mes_reservations('00000000-0000-0000-0000-000000000001') $$,
  $$ values ('00000000-0000-0000-0000-0000000000f2'::uuid, 'confirmee', false),
            ('00000000-0000-0000-0000-0000000000f3'::uuid, 'terminee',  false),
            ('00000000-0000-0000-0000-0000000000f1'::uuid, 'confirmee', true),
            ('00000000-0000-0000-0000-0000000000f4'::uuid, 'annulee',   false),
            ('00000000-0000-0000-0000-0000000000f5'::uuid, 'confirmee', true) $$,
  'Client 1 : ses 5 réservations du salon 1, par date ; annulables : confirmées à venir');

select results_eq(
  $$ select prestation, prix, duree_minutes, coiffeur, debut, fin
       from public.mes_reservations('00000000-0000-0000-0000-000000000001')
      where id = '00000000-0000-0000-0000-0000000000f5' $$,
  $$ values ('Ancienne'::varchar, 12.500::numeric, 30, 'Coiffeur A'::varchar,
             '2030-01-07 11:00+01'::timestamptz, '2030-01-07 11:30+01'::timestamptz) $$,
  'Détail : prestation (même désactivée), prix, durée, coiffeur, horaires');

select results_eq(
  $$ select id from public.mes_reservations('00000000-0000-0000-0000-000000000002') $$,
  $$ values ('00000000-0000-0000-0000-0000000000f7'::uuid) $$,
  'Client 1 dans le salon 2 : seulement celle du salon 2');

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c2');

select results_eq(
  $$ select id from public.mes_reservations('00000000-0000-0000-0000-000000000001') $$,
  $$ values ('00000000-0000-0000-0000-0000000000f6'::uuid) $$,
  'Client 2 : seulement la sienne');

-- ------------------------------------------------------------
-- Annuler la réservation d'un autre : refusé
-- ------------------------------------------------------------

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f6') $$,
  'PT404', 'Réservation introuvable', 'Client 1 : annuler celle de client 2 refusé (PT404)');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000ff') $$,
  'PT404', 'Réservation introuvable', 'Réservation inconnue : PT404, même réponse');

select results_eq(
  $$ with m as (
       update public.reservations set statut = 'annulee'
        where id in ('00000000-0000-0000-0000-0000000000f6', '00000000-0000-0000-0000-0000000000f5')
       returning 1)
     select count(*)::int from m $$,
  $$ values (0) $$,
  'Modification directe par l''API : sans effet, même sur les siennes (0 ligne)');

-- ------------------------------------------------------------
-- Réservations non annulables
-- ------------------------------------------------------------

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f2') $$,
  'PT409', 'Cette réservation ne peut plus être annulée', 'Passée (encore confirmée) : PT409');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f3') $$,
  'PT409', 'Cette réservation ne peut plus être annulée', 'Terminée : PT409');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f4') $$,
  'PT409', 'Cette réservation ne peut plus être annulée', 'Déjà annulée : PT409');

-- ------------------------------------------------------------
-- Annuler la sienne : le créneau redevient disponible
-- ------------------------------------------------------------

select is(pg_temp.creneau_9h_libre(), 0::bigint, 'Avant : 9h n''est pas proposé (réservé par client 1)');

select results_eq(
  $$ select id, statut::text from public.annuler_reservation('00000000-0000-0000-0000-0000000000f1') $$,
  $$ values ('00000000-0000-0000-0000-0000000000f1'::uuid, 'annulee') $$,
  'Client 1 : annule sa réservation à venir');

select is(pg_temp.creneau_9h_libre(), 1::bigint, 'Après : 9h est de nouveau proposé');

select throws_ok(
  $$ select * from public.annuler_reservation('00000000-0000-0000-0000-0000000000f1') $$,
  'PT409', 'Cette réservation ne peut plus être annulée', 'Annuler deux fois : PT409');

-- ------------------------------------------------------------
-- Réserver, annuler, puis réserver le même créneau : réussit
-- (creneaux_disponibles, reserver() et la contrainte d'exclusion ignorent
-- les réservations annulées). Lundi 7 janvier 2030 11h30, coiffeur A.
-- ------------------------------------------------------------

select results_eq(
  $$ select coiffeur_id from public.reserver('00000000-0000-0000-0000-0000000000e1',
       '2030-01-07 11:30+01', '00000000-0000-0000-0000-0000000000a1') $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1'::uuid) $$,
  'Client 1 réserve A à 11h30');

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c2');
select throws_ok(
  $$ select * from public.reserver('00000000-0000-0000-0000-0000000000e1',
       '2030-01-07 11:30+01', '00000000-0000-0000-0000-0000000000a1') $$,
  'PT409', 'Ce créneau n''est plus disponible', 'Client 2 : 11h30 chez A est pris');

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$ select public.annuler_reservation(r.id)
       from public.mes_reservations('00000000-0000-0000-0000-000000000001') r
      where r.debut = '2030-01-07 11:30+01' and r.statut = 'confirmee' $$,
  'Client 1 annule sa réservation de 11h30');

select pg_temp.connecter('00000000-0000-0000-0000-0000000000c2');
select results_eq(
  $$ select coiffeur_id, debut from public.reserver('00000000-0000-0000-0000-0000000000e1',
       '2030-01-07 11:30+01', '00000000-0000-0000-0000-0000000000a1') $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1'::uuid, '2030-01-07 11:30+01'::timestamptz) $$,
  'Client 2 réserve le même créneau après l''annulation : réussi');

reset role;

select results_eq(
  $$ select statut::text from public.reservations where id = '00000000-0000-0000-0000-0000000000f1' $$,
  $$ values ('annulee') $$,
  'Annulation = changement de statut, la ligne reste');

select results_eq(
  $$ select statut::text from public.reservations
      where id in ('00000000-0000-0000-0000-0000000000f5', '00000000-0000-0000-0000-0000000000f6')
      order by id $$,
  $$ values ('confirmee'), ('confirmee') $$,
  'Les réservations visées par la modification directe sont intactes');

-- ============================================================
-- Règle « annulable » écrite une seule fois (#110)
-- ============================================================

select ok(
  private.reservation_annulable('confirmee', now() + interval '1 minute')
  and not private.reservation_annulable('confirmee', now())
  and not private.reservation_annulable('confirmee', now() - interval '1 minute'),
  'Règle commune : confirmée et pas encore commencée');

select ok(
  not private.reservation_annulable('terminee', now() + interval '1 day')
  and not private.reservation_annulable('absent', now() + interval '1 day')
  and not private.reservation_annulable('annulee', now() + interval '1 day'),
  'Règle commune : terminée, absent ou annulée ne sont pas annulables');

select ok(
  pg_get_functiondef('public.mes_reservations(uuid)'::regprocedure)
    like '%private.reservation_annulable(%'
  and pg_get_functiondef('public.annuler_reservation(uuid)'::regprocedure)
    like '%private.reservation_annulable(%',
  'mes_reservations et annuler_reservation appellent la règle commune');

select ok(
  pg_get_functiondef('public.mes_reservations(uuid)'::regprocedure)
    not like '%now()%'
  and pg_get_functiondef('public.annuler_reservation(uuid)'::regprocedure)
    not like '%now()%',
  'Aucune copie de la règle (now()) dans les deux fonctions');

select ok(
  not has_function_privilege('anon',
    'private.reservation_annulable(public.statut_reservation, timestamptz, integer)', 'execute')
  and not has_function_privilege('authenticated',
    'private.reservation_annulable(public.statut_reservation, timestamptz, integer)', 'execute'),
  'Règle commune : pas appelable directement par les clients');

select * from finish();
rollback;
