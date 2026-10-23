-- Données de développement local, rejouées à chaque `supabase db reset`.
-- Jamais envoyées au distant. Mots de passe de test uniquement.
--
--   gerant@salon.test / motdepasse  (gérant + client du salon)
--   client@salon.test / motdepasse  (client du salon)

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
                '33333333-3333-3333-3333-333333333333');

-- Premier gérant : en local par le seed, en distant par SQL manuel
-- (voir docs/premier-gerant.md).
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'gerant');
