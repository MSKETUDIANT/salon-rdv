-- Issue #5 : calcul des créneaux disponibles (BF-C1 à BF-C3, BNF-2).
begin;

create extension if not exists pgtap with schema extensions;

select plan(25);

-- Jeu de données : salon à Tunis (UTC+1, sans heure d'été).
--   A : coiffeur, lundi 9h-12h et 14h-18h (horaire coupé), mardi 9h-17h ;
--       sait faire Coupe (30 min), Couleur (60 min) et Ancienne (inactive).
--       Absent lundi 10h-11h et mardi 12h-13h30. Réservé lundi 15h-15h30 et
--       mardi 9h-10h ; réservation annulée lundi 16h-16h30.
--   B : coiffeur, lundi 9h-10h, sait faire Coupe.
--   C : coiffeur, lundi 9h-18h, ne sait rien faire.
--   D : simple client avec horaires et compétence Coupe : jamais proposé.
--   E : coiffeur tous les jours 0h-23h45, ne sait faire que Brushing.
-- Lundi 7 janvier 2030 et mardi 8 janvier 2030.
insert into public.salons (id, nom, fuseau_horaire) values
  ('00000000-0000-0000-0000-000000000001', 'Salon test', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'client@creneaux.test',     '{"nom":"Client"}'),
  ('00000000-0000-0000-0000-0000000000a1', 'coiffeur-a@creneaux.test', '{"nom":"Coiffeur A"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'coiffeur-b@creneaux.test', '{"nom":"Coiffeur B"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'coiffeur-c@creneaux.test', '{"nom":"Coiffeur C"}'),
  ('00000000-0000-0000-0000-0000000000d1', 'client-d@creneaux.test',   '{"nom":"Client D"}'),
  ('00000000-0000-0000-0000-0000000000e1', 'coiffeur-e@creneaux.test', '{"nom":"Coiffeur E"}');

insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000001', 'coiffeur'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000001', 'coiffeur');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes, active) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-000000000001', 'Coupe',    20, 30, true),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-000000000001', 'Couleur',  45, 60, true),
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-000000000001', 'Ancienne', 10, 30, false),
  ('00000000-0000-0000-0000-0000000000f4', '00000000-0000-0000-0000-000000000001', 'Brushing', 15, 30, true);

insert into public.competences (coiffeur_id, prestation_id) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f2'),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f3'),
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000f4');

insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
select '00000000-0000-0000-0000-000000000001'::uuid, c::uuid, j, d::time, f::time
  from (values
    ('00000000-0000-0000-0000-0000000000a1', 1, '09:00', '12:00'),
    ('00000000-0000-0000-0000-0000000000a1', 1, '14:00', '18:00'),
    ('00000000-0000-0000-0000-0000000000a1', 2, '09:00', '17:00'),
    ('00000000-0000-0000-0000-0000000000b1', 1, '09:00', '10:00'),
    ('00000000-0000-0000-0000-0000000000c2', 1, '09:00', '18:00'),
    ('00000000-0000-0000-0000-0000000000d1', 1, '09:00', '18:00')
  ) as v(c, j, d, f)
union all
select '00000000-0000-0000-0000-000000000001'::uuid, '00000000-0000-0000-0000-0000000000e1'::uuid, j, '00:00'::time, '23:45'::time
  from generate_series(1, 7) as j;

insert into public.absences (salon_id, coiffeur_id, debut, fin) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
   '2030-01-07 10:00+01', '2030-01-07 11:00+01'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
   '2030-01-08 12:00+01', '2030-01-08 13:30+01');

insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1',
   '2030-01-07 15:00+01', '2030-01-07 15:30+01', 'confirmee'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1',
   '2030-01-07 16:00+01', '2030-01-07 16:30+01', 'annulee'),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f2',
   '2030-01-08 09:00+01', '2030-01-08 10:00+01', 'confirmee');

-- Créneaux Coupe du coiffeur A, lundi.
create temp table coupe_a as
  select * from public.creneaux_disponibles(
    '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-07',
    '00000000-0000-0000-0000-0000000000a1');

-- 1. Le salon a un fuseau horaire.
select has_column('public', 'salons', 'fuseau_horaire', 'salons.fuseau_horaire existe');

-- 2. Décompte attendu : 6 le matin (11 - 5 pris par l'absence), 12 l'après-midi
--    (15 - 3 pris par la réservation).
select is((select count(*) from coupe_a), 18::bigint, 'Coupe, A, lundi : 18 créneaux');

-- 3. Les heures sont celles du salon : 9h à Tunis = 8h UTC.
select is((select min(debut) from coupe_a), '2030-01-07 08:00+00'::timestamptz,
  'Premier créneau à 9h heure de Tunis (8h UTC)');

-- 4. Absence : aucun créneau ne la chevauche.
select is((select count(*) from coupe_a
            where debut < '2030-01-07 11:00+01' and fin > '2030-01-07 10:00+01'),
  0::bigint, 'Aucun créneau pendant l''absence 10h-11h');

-- 5. Bout à bout avec l'absence : 9h30-10h et 11h-11h30 restent proposés.
select results_eq(
  $$ select debut from coupe_a
      where debut in ('2030-01-07 09:30+01', '2030-01-07 11:00+01') order by debut $$,
  $$ values ('2030-01-07 09:30+01'::timestamptz), ('2030-01-07 11:00+01') $$,
  'Créneaux bout à bout avec l''absence proposés');

-- 6. Réservation existante : aucun créneau ne la chevauche.
select is((select count(*) from coupe_a
            where debut < '2030-01-07 15:30+01' and fin > '2030-01-07 15:00+01'),
  0::bigint, 'Aucun créneau sur la réservation 15h-15h30');

-- 7. Bout à bout avec la réservation : 14h30 et 15h30 proposés.
select results_eq(
  $$ select debut from coupe_a
      where debut in ('2030-01-07 14:30+01', '2030-01-07 15:30+01') order by debut $$,
  $$ values ('2030-01-07 14:30+01'::timestamptz), ('2030-01-07 15:30+01') $$,
  'Créneaux bout à bout avec la réservation proposés');

-- 8. Réservation annulée : elle ne bloque rien.
select ok(exists (select 1 from coupe_a where debut = '2030-01-07 16:00+01'),
  'La réservation annulée 16h-16h30 ne bloque pas le créneau');

-- 9. Fin de journée : dernier créneau 17h30-18h, rien après.
select is((select max(fin) from coupe_a), '2030-01-07 18:00+01'::timestamptz,
  'Fin de journée : aucun créneau ne dépasse 18h');

-- 10. Horaire coupé : rien entre 12h et 14h, rien qui déborde sur la pause.
select is((select count(*) from coupe_a
            where debut < '2030-01-07 14:00+01' and fin > '2030-01-07 12:00+01'),
  0::bigint, 'Horaire coupé : aucun créneau pendant la pause 12h-14h');

-- 11. Prestation plus longue (Couleur, 60 min) : le matin, seuls 9h et 11h
--     tiennent entre 9h, l'absence et midi.
select results_eq(
  $$ select debut from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f2', '2030-01-07', '2030-01-07',
       '00000000-0000-0000-0000-0000000000a1')
      where debut < '2030-01-07 12:00+01' order by debut $$,
  $$ values ('2030-01-07 09:00+01'::timestamptz), ('2030-01-07 11:00+01') $$,
  'Couleur (60 min) le matin : 9h et 11h seulement');

-- 12. Fin de journée pour 60 min : dernier début à 17h.
select is((select max(debut) from public.creneaux_disponibles(
            '00000000-0000-0000-0000-0000000000f2', '2030-01-07', '2030-01-07',
            '00000000-0000-0000-0000-0000000000a1')),
  '2030-01-07 17:00+01'::timestamptz, 'Couleur : dernier début à 17h');

-- 13. BF-C3 : un coiffeur qui ne sait pas faire la prestation n'a aucun créneau.
select is_empty(
  $$ select * from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-08',
       '00000000-0000-0000-0000-0000000000c2') $$,
  'Coiffeur C (non compétent) : aucun créneau');

-- 14. Quelqu'un qui n'est pas coiffeur du salon n'est jamais proposé.
select is_empty(
  $$ select * from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-08',
       '00000000-0000-0000-0000-0000000000d1') $$,
  'Client D (pas coiffeur) : aucun créneau');

-- 15. « Peu importe » : A et B, jamais C ni D.
select results_eq(
  $$ select distinct coiffeur_id from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-07')
      order by coiffeur_id $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1'::uuid), ('00000000-0000-0000-0000-0000000000b1') $$,
  '« Peu importe » : seuls les coiffeurs compétents A et B');

-- 16. « Peu importe » : 18 créneaux de A + 3 de B (9h, 9h15, 9h30).
select is((select count(*) from public.creneaux_disponibles(
            '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-07')),
  21::bigint, '« Peu importe », Coupe, lundi : 21 créneaux');

-- 17. Prestation inactive : aucun créneau.
select is_empty(
  $$ select * from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f3', '2030-01-07', '2030-01-08') $$,
  'Prestation inactive : aucun créneau');

-- 18. BNF-2 : chaque créneau proposé (lundi et mardi, Coupe et Couleur, tous
--     coiffeurs) est recontrôlé contre la règle de gestion centrale.
create temp table tous as
  select p.id as prestation_id, p.duree_minutes, c.*
    from public.prestations p
    cross join lateral public.creneaux_disponibles(p.id, '2030-01-07', '2030-01-08') c
   where p.id in ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000f2');

select is((
  select count(*) from tous t
   where t.fin - t.debut <> make_interval(mins => t.duree_minutes)
      or not exists (
        select 1 from public.horaires h
         where h.coiffeur_id = t.coiffeur_id
           and h.jour_semaine = extract(isodow from t.debut at time zone 'Africa/Tunis')
           and (t.debut at time zone 'Africa/Tunis')::date = (t.fin at time zone 'Africa/Tunis')::date
           and (t.debut at time zone 'Africa/Tunis')::time >= h.heure_debut
           and (t.fin at time zone 'Africa/Tunis')::time <= h.heure_fin)
      or exists (
        select 1 from public.absences a
         where a.coiffeur_id = t.coiffeur_id and a.debut < t.fin and a.fin > t.debut)
      or exists (
        select 1 from public.reservations r
         where r.coiffeur_id = t.coiffeur_id and r.statut <> 'annulee'
           and r.debut < t.fin and r.fin > t.debut)
      or not exists (
        select 1 from public.competences k
         where k.coiffeur_id = t.coiffeur_id and k.prestation_id = t.prestation_id)
  ), 0::bigint, 'BNF-2 : 0 créneau hors de la règle de gestion centrale');

select ok((select count(*) from tous) > 0, 'BNF-2 : le contrôle porte sur des créneaux réels');

-- 19. Jamais de créneau passé, même en demandant depuis hier.
select is((
  select count(*) from public.creneaux_disponibles(
    '00000000-0000-0000-0000-0000000000f4',
    (now() at time zone 'Africa/Tunis')::date - 1,
    (now() at time zone 'Africa/Tunis')::date + 1)
   where debut <= now()
  ), 0::bigint, 'Aucun créneau dans le passé');

-- 20. Fenêtre bornée à 31 jours (le jour demandé + 30).
select is((
  select max((debut at time zone 'Africa/Tunis')::date)
    from public.creneaux_disponibles(
      '00000000-0000-0000-0000-0000000000f4',
      (now() at time zone 'Africa/Tunis')::date,
      (now() at time zone 'Africa/Tunis')::date + 365)
  ), (now() at time zone 'Africa/Tunis')::date + 30, 'Fenêtre bornée à 31 jours');

-- 21. Période à l'envers : aucun créneau.
select is_empty(
  $$ select * from public.creneaux_disponibles(
       '00000000-0000-0000-0000-0000000000f1', '2030-01-08', '2030-01-07') $$,
  'Période à l''envers : aucun créneau');

-- 22. La fonction ne renvoie que des créneaux : coiffeur, début, fin.
select is(
  pg_get_function_result('public.creneaux_disponibles(uuid, date, date, uuid)'::regprocedure),
  'TABLE(coiffeur_id uuid, debut timestamp with time zone, fin timestamp with time zone)',
  'Colonnes renvoyées : coiffeur_id, debut, fin, rien d''autre');

-- 23. BF-C1 : un visiteur sans compte voit les créneaux...
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is((select count(*) from public.creneaux_disponibles(
            '00000000-0000-0000-0000-0000000000f1', '2030-01-07', '2030-01-07')),
  21::bigint, 'Visiteur sans compte : voit les 21 créneaux');

-- 24. ... sans lire les réservations ni les absences.
select is((select count(*) from public.reservations) + (select count(*) from public.absences),
  0::bigint, 'Visiteur sans compte : aucune réservation ni absence lisible');

select * from finish();
rollback;
