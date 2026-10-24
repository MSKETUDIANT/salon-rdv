-- ============================================================
-- DONNÉES DE DÉMONSTRATION — salon-rdv
-- ============================================================
-- Coiffeurs, prestations, compétences et horaires fictifs, pour montrer le
-- parcours de réservation sur le site déployé avant que le gérant configure
-- le salon (app pro, #9). Procédure : docs/donnees-demo.md.
--
-- Seul SQL manuel autorisé en distant avec docs/premier-gerant.md (CLAUDE.md).
-- Données seulement, jamais le schéma.
--
-- Idempotent : rejouable sans doublon (ids fixes, « on conflict do nothing »).
-- Toutes les lignes de démo sont repérables :
--   - ids commençant par de300000-0000-4000-8000- ;
--   - comptes coiffeurs en @demo.salon-rdv.invalid, métadonnées "demo": true.
-- Les comptes coiffeurs n'ont ni mot de passe ni identité de connexion : on ne
-- peut pas s'y connecter (domaine .invalid : aucun e-mail ne peut y arriver).
--
-- Pas d'absence ni de réservation : une réservation exige un vrai client.
--
-- Une seule instruction (bloc do, atomique : tout ou rien), exécutable par
-- `supabase db query` ou le SQL Editor. Le bloc vérifie lui-même le résultat
-- et annule tout s'il est faux. Affichage : supabase/demo/verifier-demo.sql.

do $$
declare
  v_salon uuid;
  v_nb    integer;
  v_bilan text;
begin
  -- Un seul salon en v1 : le script refuse de deviner s'il y en a 0 ou plusieurs.
  select count(*) into v_nb from public.salons;
  if v_nb <> 1 then
    raise exception 'Données de démo : il faut exactement un salon, trouvé %', v_nb;
  end if;
  select id into v_salon from public.salons;

  -- Comptes des coiffeurs. Le trigger on_auth_user_created crée la ligne
  -- utilisateurs (et le rôle client, un seul salon existant).
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values
    ('00000000-0000-0000-0000-000000000000', 'de300000-0000-4000-8000-000000000001',
     'authenticated', 'authenticated', 'amira@demo.salon-rdv.invalid', '',
     '{"provider":"email","providers":["email"],"demo":true}', '{"nom":"Amira","demo":true}',
     now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', 'de300000-0000-4000-8000-000000000002',
     'authenticated', 'authenticated', 'youssef@demo.salon-rdv.invalid', '',
     '{"provider":"email","providers":["email"],"demo":true}', '{"nom":"Youssef","demo":true}',
     now(), now(), '', '', '', '')
  on conflict (id) do nothing;

  insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
    ('de300000-0000-4000-8000-000000000001', v_salon, 'coiffeur'),
    ('de300000-0000-4000-8000-000000000002', v_salon, 'coiffeur')
  on conflict do nothing;

  insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
    ('de300000-0000-4000-8000-000000000011', v_salon, 'Coupe femme', 35, 45),
    ('de300000-0000-4000-8000-000000000012', v_salon, 'Coupe homme', 20, 30),
    ('de300000-0000-4000-8000-000000000013', v_salon, 'Brushing', 25, 30),
    ('de300000-0000-4000-8000-000000000014', v_salon, 'Couleur', 80, 90)
  on conflict (id) do nothing;

  -- Amira sait tout faire ; Youssef, les coupes seulement.
  insert into public.competences (coiffeur_id, prestation_id) values
    ('de300000-0000-4000-8000-000000000001', 'de300000-0000-4000-8000-000000000011'),
    ('de300000-0000-4000-8000-000000000001', 'de300000-0000-4000-8000-000000000012'),
    ('de300000-0000-4000-8000-000000000001', 'de300000-0000-4000-8000-000000000013'),
    ('de300000-0000-4000-8000-000000000001', 'de300000-0000-4000-8000-000000000014'),
    ('de300000-0000-4000-8000-000000000002', 'de300000-0000-4000-8000-000000000011'),
    ('de300000-0000-4000-8000-000000000002', 'de300000-0000-4000-8000-000000000012')
  on conflict do nothing;

  -- Amira : mardi-samedi, horaire coupé 9h-13h / 14h-19h (ids …101 à …110).
  -- Youssef : lundi-samedi 10h-18h (ids …201 à …206).
  insert into public.horaires (id, salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
  select format('de300000-0000-4000-8000-%s', lpad((100 + (j - 2) * 2 + p.n)::text, 12, '0'))::uuid,
         v_salon, 'de300000-0000-4000-8000-000000000001'::uuid, j, p.debut, p.fin
    from generate_series(2, 6) as j
   cross join (values (1, '09:00'::time, '13:00'::time), (2, '14:00', '19:00')) as p(n, debut, fin)
  union all
  select format('de300000-0000-4000-8000-%s', lpad((200 + j)::text, 12, '0'))::uuid,
         v_salon, 'de300000-0000-4000-8000-000000000002'::uuid, j, '10:00'::time, '18:00'::time
    from generate_series(1, 6) as j
  on conflict (id) do nothing;

  -- Contrôle : 2 coiffeurs, 4 prestations, 6 compétences, 16 horaires de démo.
  select format('%s coiffeurs, %s prestations, %s compétences, %s horaires',
    (select count(*) from public.roles_utilisateur
      where role = 'coiffeur' and utilisateur_id::text like 'de300000-0000-4000-8000-%'),
    (select count(*) from public.prestations where id::text like 'de300000-0000-4000-8000-%'),
    (select count(*) from public.competences where coiffeur_id::text like 'de300000-0000-4000-8000-%'),
    (select count(*) from public.horaires where id::text like 'de300000-0000-4000-8000-%'))
    into v_bilan;
  if v_bilan <> '2 coiffeurs, 4 prestations, 6 compétences, 16 horaires' then
    raise exception 'Données de démo incomplètes (%), rien n''est enregistré', v_bilan;
  end if;
end;
$$;
