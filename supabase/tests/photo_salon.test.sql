-- Issue #105 : photo du salon (espace de stockage « salons », salons.photo,
-- definir_photo_salon). Le format et la taille des fichiers sont contrôlés par
-- l'API Storage (réglages de l'espace, vérifiés ici) ; les droits, par la RLS
-- de storage.objects.
begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

-- Jeu de données : salons A et B.
--   gA : gérant de A ; cA : coiffeur de A ; gB : gérant de B.
insert into public.salons (id, nom, fuseau_horaire) values
  ('0000000a-0000-0000-0000-000000000105', 'Salon A', 'Africa/Tunis'),
  ('0000000b-0000-0000-0000-000000000105', 'Salon B', 'Africa/Tunis');

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000a01-0000-0000-0000-000000000105', 'ga@photo.test', '{"nom":"Gérant A"}'),
  ('00000c01-0000-0000-0000-000000000105', 'ca@photo.test', '{"nom":"Coiffeur A"}'),
  ('00000b01-0000-0000-0000-000000000105', 'gb@photo.test', '{"nom":"Gérant B"}');

delete from public.roles_utilisateur where utilisateur_id::text like '%-000000000105';
insert into public.roles_utilisateur (utilisateur_id, salon_id, role) values
  ('00000a01-0000-0000-0000-000000000105', '0000000a-0000-0000-0000-000000000105', 'gerant'),
  ('00000c01-0000-0000-0000-000000000105', '0000000a-0000-0000-0000-000000000105', 'coiffeur'),
  ('00000b01-0000-0000-0000-000000000105', '0000000b-0000-0000-0000-000000000105', 'gerant');

create function pg_temp.connecter(p_id text) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
$$;

-- ------------------------------------------------------------
-- Structure
-- ------------------------------------------------------------

select results_eq(
  $$ select public, file_size_limit, allowed_mime_types
       from storage.buckets where id = 'salons' $$,
  $$ values (true, 5242880::bigint, array['image/jpeg', 'image/png', 'image/webp']) $$,
  'Espace « salons » : public, 5 Mo, JPEG / PNG / WebP');

select has_column('public', 'salons', 'photo', 'salons.photo existe');

select ok(
  not has_function_privilege('anon', 'public.definir_photo_salon(uuid, text)', 'execute')
  and has_function_privilege('authenticated', 'public.definir_photo_salon(uuid, text)', 'execute'),
  'definir_photo_salon : exécutable par authenticated seulement');

select ok(
  (select p.prosecdef and p.proconfig @> array['search_path=""']
     from pg_proc p where p.oid = 'public.definir_photo_salon(uuid, text)'::regprocedure),
  'definir_photo_salon : security definer, search_path fixé');

-- Aucune policy ne permet d'écrire dans salons (rls_salons.test.sql) : la
-- photo ne change que par definir_photo_salon().
select is_empty(
  $$ select 1 from pg_policies
      where schemaname = 'public' and tablename = 'salons' and cmd <> 'SELECT' $$,
  'salons : aucune écriture directe (photo par definir_photo_salon)');

-- ------------------------------------------------------------
-- Envoi d'un fichier (RLS de storage.objects)
-- ------------------------------------------------------------

set local role authenticated;

select pg_temp.connecter('00000a01-0000-0000-0000-000000000105');
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('salons', '0000000a-0000-0000-0000-000000000105/p1.jpg') $$,
  'Gérant de A : envoi dans le dossier de A');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('salons', '0000000b-0000-0000-0000-000000000105/p1.jpg') $$,
  '42501', null, 'Gérant de A : envoi dans le dossier de B refusé');

select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('salons', 'pas-un-salon/p1.jpg') $$,
  '42501', null, 'Dossier qui n''est pas un salon : refusé, sans erreur de conversion');

select pg_temp.connecter('00000c01-0000-0000-0000-000000000105');
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('salons', '0000000a-0000-0000-0000-000000000105/p2.jpg') $$,
  '42501', null, 'Coiffeur de A : envoi refusé');

select is_empty(
  $$ select 1 from storage.objects
      where bucket_id = 'salons' and name like '0000000a-%' $$,
  'Coiffeur de A : ne liste pas les fichiers par l''API (lecture publique par URL)');

-- ------------------------------------------------------------
-- definir_photo_salon
-- ------------------------------------------------------------

select throws_ok(
  $$ select * from public.definir_photo_salon('0000000a-0000-0000-0000-000000000105',
       '0000000a-0000-0000-0000-000000000105/p1.jpg') $$,
  'PT403', 'Photo réservée au gérant du salon', 'Coiffeur de A : refusé (PT403)');

select pg_temp.connecter('00000b01-0000-0000-0000-000000000105');
select throws_ok(
  $$ select * from public.definir_photo_salon('0000000a-0000-0000-0000-000000000105',
       '0000000a-0000-0000-0000-000000000105/p1.jpg') $$,
  'PT403', 'Photo réservée au gérant du salon', 'Gérant de B : salon A refusé (PT403)');

select pg_temp.connecter('00000a01-0000-0000-0000-000000000105');

select throws_ok(
  $$ select * from public.definir_photo_salon('0000000a-0000-0000-0000-000000000105',
       '0000000a-0000-0000-0000-000000000105/absente.jpg') $$,
  'PT400', 'Photo introuvable', 'Fichier absent de l''espace : refusé (PT400)');

select throws_ok(
  $$ select * from public.definir_photo_salon('0000000a-0000-0000-0000-000000000105',
       '0000000b-0000-0000-0000-000000000105/p1.jpg') $$,
  'PT400', 'Photo introuvable', 'Chemin hors du dossier du salon : refusé (PT400)');

select results_eq(
  $$ select ancienne_photo from public.definir_photo_salon(
       '0000000a-0000-0000-0000-000000000105',
       '0000000a-0000-0000-0000-000000000105/p1.jpg') $$,
  $$ values (null::text) $$,
  'Gérant de A : première photo, pas d''ancienne');

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('salons', '0000000a-0000-0000-0000-000000000105/p3.jpg') $$,
  'Gérant de A : nouvelle photo envoyée');

select results_eq(
  $$ select ancienne_photo from public.definir_photo_salon(
       '0000000a-0000-0000-0000-000000000105',
       '0000000a-0000-0000-0000-000000000105/p3.jpg') $$,
  $$ values ('0000000a-0000-0000-0000-000000000105/p1.jpg') $$,
  'Changement : l''ancien chemin est renvoyé (à supprimer par l''app)');

-- La suppression d'un fichier passe par l'API Storage (la suppression SQL
-- directe est bloquée par Supabase) : la policy est vérifiée ici, l'envoi et
-- la suppression réels sur l'émulateur.
select ok(
  exists (select 1 from pg_policies
           where schemaname = 'storage' and tablename = 'objects'
             and policyname = 'salons : gérant supprime la photo' and cmd = 'DELETE'),
  'Policy de suppression des fichiers du salon par son gérant');

select results_eq(
  $$ select ancienne_photo from public.definir_photo_salon(
       '0000000a-0000-0000-0000-000000000105', null) $$,
  $$ values ('0000000a-0000-0000-0000-000000000105/p3.jpg') $$,
  'Retrait : retour à l''image par défaut, ancien chemin renvoyé');

-- Lecture publique de salons.photo (site et app, sans compte).
reset role;
set local role anon;
select results_eq(
  $$ select photo from public.salons where id = '0000000a-0000-0000-0000-000000000105' $$,
  $$ values (null::text) $$,
  'anon lit salons.photo');

select * from finish();
rollback;
