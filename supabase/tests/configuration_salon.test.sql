-- Issue #9 : configuration du salon (BF-G1 à G3). Seul le gérant du salon
-- écrit horaires, absences, prestations et compétences, même par appel direct
-- à l'API (BNF-3). Chaque réglage change aussitôt les créneaux proposés.
begin;

create extension if not exists pgtap with schema extensions;

select plan(71);

-- Jeu de données : salons A et B, à Tunis (UTC+1).
--   gA : gérant de A ; cA : coiffeur de A (pas gérant) ; clA : client de A.
--   gB : gérant de B ; cB : coiffeur de B ; gAB : gérant de A et de B.
--   pA : Coupe (30 min) de A, que cA sait faire ; pB : prestation de B.
--   hA : cA travaille le lundi 9h-12h ; aA : absence de cA.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000009', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000009', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000009', 'ga@config.test',  '{"nom":"Gérant A"}'),
  ('00000a02-0000-0000-0000-000000000009', 'ca@config.test',  '{"nom":"Coiffeur A"}'),
  ('00000a03-0000-0000-0000-000000000009', 'cla@config.test', '{"nom":"Client A"}'),
  ('00000b01-0000-0000-0000-000000000009', 'gb@config.test',  '{"nom":"Gérant B"}'),
  ('00000b02-0000-0000-0000-000000000009', 'cb@config.test',  '{"nom":"Coiffeur B"}'),
  ('00000ab1-0000-0000-0000-000000000009', 'gab@config.test', '{"nom":"Gérant A et B"}');

-- Le trigger n'attribue le rôle client que s'il n'existe qu'un salon : rôles
-- posés ici.
delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000009';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'gerant'),
  ('00000a02-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'coiffeur'),
  ('00000a03-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'client'),
  ('00000b01-0000-0000-0000-000000000009', '0000000b-0000-0000-0000-000000000009', 'gerant'),
  ('00000b02-0000-0000-0000-000000000009', '0000000b-0000-0000-0000-000000000009', 'coiffeur'),
  ('00000ab1-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'gerant'),
  ('00000ab1-0000-0000-0000-000000000009', '0000000b-0000-0000-0000-000000000009', 'gerant');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('0000f0a1-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'Coupe', 20, 30),
  ('0000f0b1-0000-0000-0000-000000000009', '0000000b-0000-0000-0000-000000000009', 'Coupe B', 25, 30);

insert into public.competences (coiffeur_id, prestation_id) values
  ('00000a02-0000-0000-0000-000000000009', '0000f0a1-0000-0000-0000-000000000009');

insert into public.horaires (id, salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin) values
  ('0000a0a1-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009',
   '00000a02-0000-0000-0000-000000000009', 1, '09:00', '12:00');

insert into public.absences (id, salon_id, coiffeur_id, debut, fin, motif) values
  ('0000ab51-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009',
   '00000a02-0000-0000-0000-000000000009', '2030-01-14 09:00+01', '2030-01-14 12:00+01', 'Formation');

-- Se connecter comme un utilisateur donné.
create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- Nombre de lignes touchées par une instruction (0 : sans effet sous RLS).
create function pg_temp.lignes(p_sql text) returns int language plpgsql as $$
declare n int;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return n;
end;
$$;

-- Créneaux de Coupe proposés le lundi 7 janvier 2030 (cA seul coiffeur).
create function pg_temp.creneaux_lundi() returns bigint language sql as $$
  select count(*) from public.creneaux_disponibles(
    '0000f0a1-0000-0000-0000-000000000009', '2030-01-07', '2030-01-07');
$$;

-- ------------------------------------------------------------
-- Socle : btree_gist (contraintes d'exclusion), activée par la migration #1
-- ------------------------------------------------------------

select has_extension('extensions', 'btree_gist', 'btree_gist activée (migration 20261022224513, #1)');

-- ------------------------------------------------------------
-- Lecture : horaires et absences jamais sans compte
-- ------------------------------------------------------------

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select throws_ok($$ select count(*) from public.horaires $$, '42501', null, 'Sans compte : horaires illisibles');
select throws_ok($$ select count(*) from public.absences $$, '42501', null, 'Sans compte : absences illisibles');
reset role;

set local role authenticated;

select pg_temp.connecter('00000a03-0000-0000-0000-000000000009');
select is((select count(*)::int from public.horaires where salon_id = '0000000a-0000-0000-0000-000000000009'),
  1, 'Client de A : lit les horaires de A');
select is((select count(*)::int from public.absences), 0, 'Client de A : aucune absence lisible');

select pg_temp.connecter('00000b02-0000-0000-0000-000000000009');
select is((select count(*)::int from public.horaires where salon_id = '0000000a-0000-0000-0000-000000000009'),
  0, 'Coiffeur de B : horaires de A illisibles');
select is((select count(*)::int from public.absences where salon_id = '0000000a-0000-0000-0000-000000000009'),
  0, 'Coiffeur de B : absences de A illisibles');

select pg_temp.connecter('00000a02-0000-0000-0000-000000000009');
select is((select count(*)::int from public.horaires), 1, 'Coiffeur de A : lit les horaires de son salon');
select is((select count(*)::int from public.absences), 1, 'Coiffeur de A : lit son absence');

-- ------------------------------------------------------------
-- Coiffeur non gérant : aucune écriture (BNF-3)
-- ------------------------------------------------------------

select pg_temp.connecter('00000a02-0000-0000-0000-000000000009');

select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 2, '09:00', '12:00') $$,
  '42501', null, 'Coiffeur A : créer son horaire refusé');
select is(pg_temp.lignes($$ update public.horaires set heure_fin = '20:00' where id = '0000a0a1-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : modifier son horaire sans effet');
select is(pg_temp.lignes($$ delete from public.horaires where id = '0000a0a1-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : supprimer son horaire sans effet');

select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', '2030-02-01 09:00+01', '2030-02-01 10:00+01') $$,
  '42501', null, 'Coiffeur A : déclarer une absence refusé');
select is(pg_temp.lignes($$ update public.absences set fin = '2030-01-14 18:00+01' where id = '0000ab51-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : modifier son absence sans effet');
select is(pg_temp.lignes($$ delete from public.absences where id = '0000ab51-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : supprimer son absence sans effet');

select throws_ok(
  $$ insert into public.prestations (salon_id, nom, prix, duree_minutes)
     values ('0000000a-0000-0000-0000-000000000009', 'Promo', 1, 30) $$,
  '42501', null, 'Coiffeur A : créer une prestation refusé');
select is(pg_temp.lignes($$ update public.prestations set prix = 1 where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : changer un prix sans effet');
select is(pg_temp.lignes($$ update public.prestations set active = false where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : désactiver une prestation sans effet');
select is(pg_temp.lignes($$ delete from public.prestations where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : supprimer une prestation sans effet');

select throws_ok(
  $$ insert into public.competences (coiffeur_id, prestation_id)
     values ('00000a02-0000-0000-0000-000000000009', '0000f0b1-0000-0000-0000-000000000009') $$,
  '42501', null, 'Coiffeur A : s''ajouter une compétence refusé');
select is(pg_temp.lignes($$ delete from public.competences where coiffeur_id = '00000a02-0000-0000-0000-000000000009' $$),
  0, 'Coiffeur A : retirer sa compétence sans effet');

-- ------------------------------------------------------------
-- Client : aucune écriture
-- ------------------------------------------------------------

select pg_temp.connecter('00000a03-0000-0000-0000-000000000009');

select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 3, '09:00', '12:00') $$,
  '42501', null, 'Client A : créer un horaire refusé');
select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', '2030-02-01 09:00+01', '2030-02-01 10:00+01') $$,
  '42501', null, 'Client A : créer une absence refusé');
select throws_ok(
  $$ insert into public.prestations (salon_id, nom, prix, duree_minutes)
     values ('0000000a-0000-0000-0000-000000000009', 'Promo', 1, 30) $$,
  '42501', null, 'Client A : créer une prestation refusé');
select is(pg_temp.lignes($$ update public.prestations set prix = 1 where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Client A : changer un prix sans effet');
select throws_ok(
  $$ insert into public.competences (coiffeur_id, prestation_id)
     values ('00000a02-0000-0000-0000-000000000009', '0000f0b1-0000-0000-0000-000000000009') $$,
  '42501', null, 'Client A : ajouter une compétence refusé');

-- ------------------------------------------------------------
-- Gérant d'un autre salon : aucune écriture sur A
-- ------------------------------------------------------------

select pg_temp.connecter('00000b01-0000-0000-0000-000000000009');

select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 2, '09:00', '12:00') $$,
  '42501', null, 'Gérant B : horaire dans le salon A refusé');
select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000b-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 2, '09:00', '12:00') $$,
  '42501', null, 'Gérant B : horaire dans B pour le coiffeur de A refusé');
select is(pg_temp.lignes($$ delete from public.horaires where id = '0000a0a1-0000-0000-0000-000000000009' $$),
  0, 'Gérant B : supprimer un horaire de A sans effet');
select is(pg_temp.lignes($$ delete from public.absences where id = '0000ab51-0000-0000-0000-000000000009' $$),
  0, 'Gérant B : supprimer une absence de A sans effet');
select is(pg_temp.lignes($$ update public.prestations set prix = 1 where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Gérant B : changer un prix de A sans effet');
select throws_ok(
  $$ insert into public.competences (coiffeur_id, prestation_id)
     values ('00000b02-0000-0000-0000-000000000009', '0000f0a1-0000-0000-0000-000000000009') $$,
  '42501', null, 'Gérant B : compétence sur une prestation de A refusée');
select is(pg_temp.lignes($$ delete from public.competences where prestation_id = '0000f0a1-0000-0000-0000-000000000009' $$),
  0, 'Gérant B : retirer une compétence de A sans effet');

-- ------------------------------------------------------------
-- Gérant du salon : horaires (BF-G1), effet immédiat sur les créneaux
-- ------------------------------------------------------------

select pg_temp.connecter('00000a01-0000-0000-0000-000000000009');

-- 9h-12h, Coupe de 30 min, pas de 15 min : départs de 9h00 à 11h30.
select is(pg_temp.creneaux_lundi(), 11::bigint, 'Avant : 11 créneaux le lundi (9h00 à 11h30)');

select lives_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 1, '14:00', '15:00') $$,
  'Gérant A : deuxième plage le même jour (14h-15h)');
select is(pg_temp.creneaux_lundi(), 14::bigint, 'Plage ajoutée : 3 créneaux de plus, aussitôt');

select lives_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 1, '12:00', '13:00') $$,
  'Gérant A : plage bout à bout (12h-13h) acceptée');
select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 1, '11:00', '12:30') $$,
  '23P01', null, 'Plage qui en recouvre une autre (11h-12h30) refusée');
select throws_ok(
  $$ insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009', 2, '12:00', '09:00') $$,
  '23514', null, 'Plage dont la fin précède le début refusée');

select is(pg_temp.lignes($$ update public.horaires set heure_fin = '10:00' where id = '0000a0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : raccourcit la plage du matin (9h-10h)');
select is(pg_temp.creneaux_lundi(), 9::bigint, 'Plage raccourcie : 9h-10h (3) + 12h-13h (3) + 14h-15h (3)');

select is(pg_temp.lignes($$ delete from public.horaires
                             where coiffeur_id = '00000a02-0000-0000-0000-000000000009' and heure_debut in ('12:00', '14:00') $$),
  2, 'Gérant A : supprime les deux plages ajoutées');
select is(pg_temp.creneaux_lundi(), 3::bigint, 'Plages supprimées : il reste 9h-10h');

-- ------------------------------------------------------------
-- Gérant du salon : absences (BF-G1)
-- ------------------------------------------------------------

select lives_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin, motif)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009',
             '2030-01-07 09:00+01', '2030-01-07 09:30+01', null) $$,
  'Gérant A : absence de cA lundi 9h-9h30, sans motif');
select is(pg_temp.creneaux_lundi(), 1::bigint, 'Absence : seul 9h30 reste proposé');
select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a02-0000-0000-0000-000000000009',
             '2030-01-07 10:00+01', '2030-01-07 09:00+01') $$,
  '23514', null, 'Absence dont la fin précède le début refusée');
select throws_ok(
  $$ insert into public.absences (salon_id, coiffeur_id, debut, fin)
     values ('0000000a-0000-0000-0000-000000000009', '00000a01-0000-0000-0000-000000000009',
             '2030-01-07 09:00+01', '2030-01-07 10:00+01') $$,
  '42501', null, 'Absence pour quelqu''un qui n''est pas coiffeur du salon refusée');
select is(pg_temp.lignes($$ delete from public.absences where debut = '2030-01-07 09:00+01' $$),
  1, 'Gérant A : supprime l''absence');
select is(pg_temp.creneaux_lundi(), 3::bigint, 'Absence supprimée : 3 créneaux de nouveau');

-- ------------------------------------------------------------
-- Gérant du salon : catalogue (BF-G2)
-- ------------------------------------------------------------

select lives_ok(
  $$ insert into public.prestations (id, salon_id, nom, prix, duree_minutes)
     values ('0000f0a2-0000-0000-0000-000000000009', '0000000a-0000-0000-0000-000000000009', 'Barbe', 10.500, 15) $$,
  'Gérant A : crée une prestation');
select is(pg_temp.lignes($$ update public.prestations set nom = 'Coupe courte', prix = 22, duree_minutes = 30
                             where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : modifie nom, prix et durée');
select throws_ok(
  $$ update public.prestations set salon_id = '0000000b-0000-0000-0000-000000000009'
      where id = '0000f0a1-0000-0000-0000-000000000009' $$,
  '42501', null, 'Gérant A : changer le salon d''une prestation refusé (colonne)');
-- La policy seule le laisserait passer pour un gérant des deux salons : c'est
-- le droit par colonne (migration de #9) qui le refuse.
select pg_temp.connecter('00000ab1-0000-0000-0000-000000000009');
select throws_ok(
  $$ update public.prestations set salon_id = '0000000b-0000-0000-0000-000000000009'
      where id = '0000f0a1-0000-0000-0000-000000000009' $$,
  '42501', null, 'Gérant de A et de B : déplacer une prestation de A vers B refusé');
select pg_temp.connecter('00000a01-0000-0000-0000-000000000009');
select throws_ok(
  $$ insert into public.prestations (salon_id, nom, prix, duree_minutes)
     values ('0000000a-0000-0000-0000-000000000009', '   ', 10, 30) $$,
  '23514', null, 'Nom vide refusé');
select throws_ok(
  $$ insert into public.prestations (salon_id, nom, prix, duree_minutes)
     values ('0000000a-0000-0000-0000-000000000009', 'Gratuit ?', -1, 30) $$,
  '23514', null, 'Prix négatif refusé');
select throws_ok(
  $$ insert into public.prestations (salon_id, nom, prix, duree_minutes)
     values ('0000000a-0000-0000-0000-000000000009', 'Éclair', 10, 0) $$,
  '23514', null, 'Durée nulle refusée');

select is(pg_temp.lignes($$ update public.prestations set active = false where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : désactive la Coupe');
select is(pg_temp.creneaux_lundi(), 0::bigint, 'Prestation désactivée : plus aucun créneau proposé');
select is(
  (select count(*)::int from public.prestations where id = '0000f0a1-0000-0000-0000-000000000009'),
  1, 'Prestation désactivée : la ligne reste (historique), le gérant la voit');
select is(pg_temp.lignes($$ update public.prestations set active = true where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : réactive la Coupe');

-- ------------------------------------------------------------
-- Gérant du salon : compétences (BF-G3)
-- ------------------------------------------------------------

select is(pg_temp.lignes($$ delete from public.competences
                             where coiffeur_id = '00000a02-0000-0000-0000-000000000009'
                               and prestation_id = '0000f0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : retire la Coupe à cA');
select is(pg_temp.creneaux_lundi(), 0::bigint, 'Compétence retirée : cA n''est plus proposé pour la Coupe');
select lives_ok(
  $$ insert into public.competences (coiffeur_id, prestation_id)
     values ('00000a02-0000-0000-0000-000000000009', '0000f0a1-0000-0000-0000-000000000009') $$,
  'Gérant A : rend la Coupe à cA');
select is(pg_temp.creneaux_lundi(), 3::bigint, 'Compétence rendue : 3 créneaux de nouveau');

-- ------------------------------------------------------------
-- Allonger une prestation ne change pas les rendez-vous existants : la fin
-- est enregistrée au moment de la réservation (reserver(), #6)
-- ------------------------------------------------------------

select pg_temp.connecter('00000a03-0000-0000-0000-000000000009');
select results_eq(
  $$ select fin from public.reserver('0000f0a1-0000-0000-0000-000000000009', '2030-01-07 09:00+01') $$,
  $$ values ('2030-01-07 09:30+01'::timestamptz) $$,
  'Client A réserve la Coupe (30 min) lundi 9h : fin 9h30');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000009');
select is(pg_temp.lignes($$ update public.prestations set duree_minutes = 60 where id = '0000f0a1-0000-0000-0000-000000000009' $$),
  1, 'Gérant A : allonge la Coupe à 60 min');

reset role;
select results_eq(
  $$ select debut, fin from public.reservations
      where prestation_id = '0000f0a1-0000-0000-0000-000000000009' and statut <> 'annulee' $$,
  $$ values ('2030-01-07 09:00+01'::timestamptz, '2030-01-07 09:30+01'::timestamptz) $$,
  'Le rendez-vous garde sa fin (9h30), pas debut + nouvelle durée');
set local role authenticated;
select pg_temp.connecter('00000a01-0000-0000-0000-000000000009');
-- 60 min dans la plage 9h-10h : seul 9h00 tiendrait, et il chevauche le rendez-vous.
select is(pg_temp.creneaux_lundi(), 0::bigint, 'La nouvelle durée vaut pour les nouveaux créneaux seulement');

-- ------------------------------------------------------------
-- Après coup, hors RLS : ce que les autres ont tenté n'a rien changé
-- ------------------------------------------------------------

reset role;

select results_eq(
  $$ select heure_debut::text, heure_fin::text from public.horaires
      where coiffeur_id = '00000a02-0000-0000-0000-000000000009' order by heure_debut $$,
  $$ values ('09:00:00', '10:00:00') $$,
  'Horaires de cA : seulement ce que le gérant A a fait');
select results_eq(
  $$ select fin from public.absences where id = '0000ab51-0000-0000-0000-000000000009' $$,
  $$ values ('2030-01-14 12:00+01'::timestamptz) $$,
  'Absence de cA intacte');
select results_eq(
  $$ select salon_id, prix from public.prestations where id = '0000f0a1-0000-0000-0000-000000000009' $$,
  $$ values ('0000000a-0000-0000-0000-000000000009'::uuid, 22::numeric) $$,
  'Coupe : toujours dans A, prix fixé par le gérant A seulement');

select * from finish();
rollback;
