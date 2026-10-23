-- Issue #1 : la base refuse une double réservation (BNF-1).
begin;

create extension if not exists pgtap with schema extensions;

select plan(7);

-- Jeu de données : 1 salon, 1 client, 2 coiffeurs, 1 prestation.
insert into public.salons (id, nom) values
  ('00000000-0000-0000-0000-000000000001', 'Salon test');

-- Comptes auth : le trigger on_auth_user_created crée les lignes utilisateurs.
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', 'client@chevauchement.test',  '{"nom":"Client"}'),
  ('00000000-0000-0000-0000-0000000000a1', 'coiffeur-a@chevauchement.test', '{"nom":"Coiffeur A"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'coiffeur-b@chevauchement.test', '{"nom":"Coiffeur B"}');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-000000000001', 'Coupe', 20, 30);

-- Insère une réservation pour un coiffeur sur une plage donnée.
prepare reserver(uuid, timestamptz, timestamptz) as
  insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
  values ('00000000-0000-0000-0000-000000000001',
          '00000000-0000-0000-0000-0000000000c1',
          $1,
          '00000000-0000-0000-0000-0000000000f1',
          $2, $3);

-- 1. Une première réservation est acceptée.
select lives_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000a1',
                      '2026-11-02 10:00+00', '2026-11-02 10:30+00') $$,
  'Réservation 10h00-10h30 du coiffeur A acceptée'
);

-- 2. Même plage, même coiffeur : refusée (violation d'exclusion 23P01).
select throws_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000a1',
                      '2026-11-02 10:00+00', '2026-11-02 10:30+00') $$,
  '23P01',
  null,
  'Même plage, même coiffeur : double réservation refusée'
);

-- 3. Chevauchement partiel, même coiffeur : refusé.
select throws_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000a1',
                      '2026-11-02 10:15+00', '2026-11-02 10:45+00') $$,
  '23P01',
  null,
  'Chevauchement partiel (10h15-10h45), même coiffeur : refusé'
);

-- 4. Même plage, autre coiffeur : acceptée.
select lives_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000b1',
                      '2026-11-02 10:00+00', '2026-11-02 10:30+00') $$,
  'Même plage 10h00-10h30 pour le coiffeur B : acceptée'
);

-- 5. Bout à bout, même coiffeur : acceptée (borne '[)').
select lives_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000a1',
                      '2026-11-02 10:30+00', '2026-11-02 11:00+00') $$,
  'Réservation bout à bout 10h30-11h00 du coiffeur A : acceptée'
);

-- 6. Après annulation de la première, la plage redevient libre.
update public.reservations
   set statut = 'annulee'
 where coiffeur_id = '00000000-0000-0000-0000-0000000000a1'
   and debut = '2026-11-02 10:00+00';

select lives_ok(
  $$ execute reserver('00000000-0000-0000-0000-0000000000a1',
                      '2026-11-02 10:00+00', '2026-11-02 10:30+00') $$,
  'Plage 10h00-10h30 libérée par l''annulation : nouvelle réservation acceptée'
);

-- 7. Réactiver une réservation annulée : interdit par le métier (issue #3,
-- trigger des transitions de statut). Les doublons restent couverts par 2 et 3.
select throws_ok(
  $$ update public.reservations
        set statut = 'confirmee'
      where coiffeur_id = '00000000-0000-0000-0000-0000000000a1'
        and statut = 'annulee' $$,
  '23514',
  null,
  'Réactiver une réservation annulée : transition refusée'
);

select * from finish();

rollback;
