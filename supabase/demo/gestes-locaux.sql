-- Rendez-vous d'Amira calés sur l'heure actuelle, pour essayer à toute heure
-- l'onglet « Aujourd'hui » et ses gestes dans l'app pro (#64).
--
-- BASE LOCALE UNIQUEMENT (comptes du seed, supabase/seed.sql) : le script
-- s'arrête s'il ne trouve pas Amira (44444444-…). Relançable à tout moment :
-- il remplace ses propres rendez-vous (identifiants ae570000-…) et annule les
-- rendez-vous confirmés d'Amira qui chevauchent ses créneaux.
-- Commande : pro/README.md, « Essayer les gestes ».
--
-- Créés (N = maintenant, à la minute) :
--   terminé      N - 1 h 55 → N - 1 h 25
--   absent       N - 1 h 20 → N - 50 min
--   à clôturer   N - 45 min → N - 15 min   (glissable)
--   en cours     N - 10 min → N + 20 min   (glissable)
--   à venir      N + 40 min → N + 1 h 10
--   à venir      N + 1 h 30 → N + 2 h 15
-- Près de minuit, une partie tombe sur la veille ou le lendemain.

do $$
declare
  v_salon    constant uuid := '11111111-1111-1111-1111-111111111111';
  v_amira    constant uuid := '44444444-4444-4444-4444-444444444444';
  v_client   constant uuid := '33333333-3333-3333-3333-333333333333';
  v_gerant   constant uuid := '22222222-2222-2222-2222-222222222222';
  v_coupe_f  constant uuid := '66666666-0000-0000-0000-000000000001';
  v_coupe_h  constant uuid := '66666666-0000-0000-0000-000000000002';
  v_brushing constant uuid := '66666666-0000-0000-0000-000000000003';
  v_n        constant timestamptz := date_trunc('minute', now());
begin
  if not exists (select 1 from public.utilisateurs where id = v_amira) then
    raise exception 'Script réservé à la base locale (compte Amira du seed absent).';
  end if;

  -- Rendez-vous d'un lancement précédent (et leurs encaissements).
  delete from public.encaissements
   where reservation_id::text like 'ae570000-%';
  delete from public.reservations
   where id::text like 'ae570000-%';

  -- Place libre : annule les rendez-vous confirmés d'Amira sur la fenêtre.
  update public.reservations
     set statut = 'annulee'
   where coiffeur_id = v_amira
     and statut = 'confirmee'
     and tstzrange(debut, fin, '[)')
         && tstzrange(v_n - interval '115 minutes', v_n + interval '135 minutes', '[)');

  insert into public.reservations
    (id, salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut)
  values
    ('ae570000-0000-4000-8000-000000000001', v_salon, v_client, v_amira, v_coupe_h,
     v_n - interval '115 minutes', v_n - interval '85 minutes', 'terminee'),
    ('ae570000-0000-4000-8000-000000000002', v_salon, v_gerant, v_amira, v_brushing,
     v_n - interval '80 minutes', v_n - interval '50 minutes', 'absent'),
    ('ae570000-0000-4000-8000-000000000003', v_salon, v_client, v_amira, v_coupe_h,
     v_n - interval '45 minutes', v_n - interval '15 minutes', 'confirmee'),
    ('ae570000-0000-4000-8000-000000000004', v_salon, v_gerant, v_amira, v_coupe_h,
     v_n - interval '10 minutes', v_n + interval '20 minutes', 'confirmee'),
    ('ae570000-0000-4000-8000-000000000005', v_salon, v_client, v_amira, v_brushing,
     v_n + interval '40 minutes', v_n + interval '70 minutes', 'confirmee'),
    ('ae570000-0000-4000-8000-000000000006', v_salon, v_gerant, v_amira, v_coupe_f,
     v_n + interval '90 minutes', v_n + interval '135 minutes', 'confirmee');

  raise notice 'Rendez-vous d''Amira créés autour de % (heure du salon).',
    to_char(v_n at time zone 'Africa/Tunis', 'HH24:MI');
end $$;
