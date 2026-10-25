-- Données de développement local, rejouées à chaque `supabase db reset`.
-- Jamais envoyées au distant. Mots de passe de test uniquement.
--
--   gerant@salon.test / motdepasse  (gérant + client du salon)
--   client@salon.test / motdepasse  (client du salon)
--   amira@salon.test  / motdepasse  (coiffeuse : toutes les prestations)
--   youssef@salon.test / motdepasse (coiffeur : coupes seulement)
--   patron@salon.test / motdepasse  (gérant + coiffeur, sans compétence ni
--                                    horaires : bascule de l'app pro, #8)

insert into public.salons (id, nom, adresse) values
  ('11111111-1111-1111-1111-111111111111', 'Salon de démo', '1 rue de la Coupe');

-- Le trigger on_auth_user_created crée la ligne utilisateurs et le rôle client
-- (un seul salon existe).
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'gerant@salon.test',
   extensions.crypt('motdepasse', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"nom":"Gérant Démo"}', now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'client@salon.test',
   extensions.crypt('motdepasse', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"nom":"Client Démo"}', now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444',
   'authenticated', 'authenticated', 'amira@salon.test',
   extensions.crypt('motdepasse', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"nom":"Amira"}', now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '55555555-5555-5555-5555-555555555555',
   'authenticated', 'authenticated', 'youssef@salon.test',
   extensions.crypt('motdepasse', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"nom":"Youssef"}', now(), now(),
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '77777777-7777-7777-7777-777777777777',
   'authenticated', 'authenticated', 'patron@salon.test',
   extensions.crypt('motdepasse', extensions.gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}', '{"nom":"Patron Démo"}', now(), now(),
   '', '', '', '');

-- Identités e-mail, nécessaires pour se connecter avec ces comptes.
insert into auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
  from auth.users u
 where u.id in ('22222222-2222-2222-2222-222222222222',
                '33333333-3333-3333-3333-333333333333',
                '44444444-4444-4444-4444-444444444444',
                '55555555-5555-5555-5555-555555555555',
                '77777777-7777-7777-7777-777777777777');

-- Premier gérant : en local par le seed, en distant par SQL manuel
-- (voir docs/premier-gerant.md).
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'gerant');

-- Issue #8 : un gérant qui est aussi coiffeur (bascule entre les deux espaces
-- de l'app pro). Sans compétence ni horaires : il n'apparaît dans aucun
-- créneau ni dans les filtres du site.
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'gerant'),
  ('77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'coiffeur');

-- ============================================================
-- Issue #5 : de quoi afficher des créneaux
-- ============================================================

insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'coiffeur'),
  ('55555555-5555-5555-5555-555555555555', '11111111-1111-1111-1111-111111111111', 'coiffeur');

insert into public.prestations (id, salon_id, nom, prix, duree_minutes) values
  ('66666666-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Coupe femme', 35, 45),
  ('66666666-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Coupe homme', 20, 30),
  ('66666666-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Brushing', 25, 30),
  ('66666666-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'Couleur', 80, 90);

-- Amira sait tout faire ; Youssef, les coupes seulement.
insert into public.competences (coiffeur_id, prestation_id) values
  ('44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000001'),
  ('44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000002'),
  ('44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000003'),
  ('44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000004'),
  ('55555555-5555-5555-5555-555555555555', '66666666-0000-0000-0000-000000000001'),
  ('55555555-5555-5555-5555-555555555555', '66666666-0000-0000-0000-000000000002');

-- Amira : mardi-samedi, horaire coupé 9h-13h / 14h-19h. Youssef : lundi-samedi 10h-18h.
insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
select '11111111-1111-1111-1111-111111111111'::uuid, '44444444-4444-4444-4444-444444444444'::uuid,
       j, plage.debut, plage.fin
  from generate_series(2, 6) as j
 cross join (values ('09:00'::time, '13:00'::time), ('14:00', '19:00')) as plage(debut, fin)
union all
select '11111111-1111-1111-1111-111111111111'::uuid, '55555555-5555-5555-5555-555555555555'::uuid,
       j, '10:00'::time, '18:00'::time
  from generate_series(1, 6) as j;

-- Prochain mardi (heure de Tunis), jour où les deux travaillent : Youssef absent
-- 14h-16h, Amira réservée 10h-10h45.
insert into public.absences (salon_id, coiffeur_id, debut, fin, motif)
select '11111111-1111-1111-1111-111111111111', '55555555-5555-5555-5555-555555555555',
       (mardi + time '14:00') at time zone 'Africa/Tunis',
       (mardi + time '16:00') at time zone 'Africa/Tunis',
       'Formation'
  from (select aujourdhui + 1 + (9 - extract(isodow from aujourdhui + 1)::int) % 7 as mardi
          from (select (now() at time zone 'Africa/Tunis')::date as aujourdhui) as t) as d;

insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
select '11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
       '44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000001',
       (mardi + time '10:00') at time zone 'Africa/Tunis',
       (mardi + time '10:45') at time zone 'Africa/Tunis'
  from (select aujourdhui + 1 + (9 - extract(isodow from aujourdhui + 1)::int) % 7 as mardi
          from (select (now() at time zone 'Africa/Tunis')::date as aujourdhui) as t) as d;

-- ============================================================
-- Issue #10 : de quoi tester les plannings de l'app pro
-- ============================================================

-- Téléphone du client démo (affiché dans la fiche d'un rendez-vous). Unique :
-- différent de ceux des tests SQL.
update public.utilisateurs set telephone = '21698765432'
 where id = '33333333-3333-3333-3333-333333333333';

-- Même mardi : Amira a aussi une absence (16h-17h) ; mercredi : deux rendez-vous.
insert into public.absences (salon_id, coiffeur_id, debut, fin, motif)
select '11111111-1111-1111-1111-111111111111', '44444444-4444-4444-4444-444444444444',
       (mardi + time '16:00') at time zone 'Africa/Tunis',
       (mardi + time '17:00') at time zone 'Africa/Tunis',
       'Rendez-vous médical'
  from (select aujourdhui + 1 + (9 - extract(isodow from aujourdhui + 1)::int) % 7 as mardi
          from (select (now() at time zone 'Africa/Tunis')::date as aujourdhui) as t) as d;

-- Clients : 3333… (Client Démo, avec téléphone), 2222… (Gérant Démo, sans).
-- Le rendez-vous annulé d'Amira (17h30) ne doit apparaître dans aucun planning.
insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin, statut)
select '11111111-1111-1111-1111-111111111111', r.client_id::uuid, r.coiffeur_id::uuid,
       r.prestation_id::uuid,
       (d.mardi + r.jour + r.debut) at time zone 'Africa/Tunis',
       (d.mardi + r.jour + r.fin) at time zone 'Africa/Tunis',
       r.statut::public.statut_reservation
  from (select aujourdhui + 1 + (9 - extract(isodow from aujourdhui + 1)::int) % 7 as mardi
          from (select (now() at time zone 'Africa/Tunis')::date as aujourdhui) as t) as d
 cross join (values
   -- Amira, mardi
   (0, time '11:00', time '12:30', '22222222-2222-2222-2222-222222222222',
    '44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000004', 'confirmee'),
   (0, time '14:30', time '15:00', '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000003', 'confirmee'),
   (0, time '17:30', time '18:15', '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000001', 'annulee'),
   -- Youssef, mardi (absent 14h-16h)
   (0, time '10:30', time '11:00', '33333333-3333-3333-3333-333333333333',
    '55555555-5555-5555-5555-555555555555', '66666666-0000-0000-0000-000000000002', 'confirmee'),
   (0, time '16:30', time '17:15', '22222222-2222-2222-2222-222222222222',
    '55555555-5555-5555-5555-555555555555', '66666666-0000-0000-0000-000000000001', 'confirmee'),
   -- Mercredi
   (1, time '09:00', time '09:30', '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444', '66666666-0000-0000-0000-000000000002', 'confirmee'),
   (1, time '12:00', time '12:30', '22222222-2222-2222-2222-222222222222',
    '55555555-5555-5555-5555-555555555555', '66666666-0000-0000-0000-000000000002', 'confirmee')
 ) as r(jour, debut, fin, client_id, coiffeur_id, prestation_id, statut);
