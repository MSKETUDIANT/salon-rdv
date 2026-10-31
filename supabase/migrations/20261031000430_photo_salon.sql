-- Issue #105 : vraie photo du salon (options 1A et 2a de Sparta, 2026-10-31).
-- La photo est un fichier de Supabase Storage, dans l'espace public
-- « salons », rangé sous « <id du salon>/<nom unique>.jpg » ; salons.photo
-- garde son chemin. Un nom nouveau à chaque envoi : l'ancienne image en cache
-- (navigateur, CDN) n'est jamais resservie.
--
-- Règles :
--   1. lecture : publique (photo de vitrine, rien de secret) ;
--   2. envoi et suppression d'un fichier : seulement le gérant du salon du
--      dossier ; JPEG, PNG ou WebP, 5 Mo au plus ;
--   3. salons.photo : seulement par definir_photo_salon(), gérant du salon,
--      chemin dans le dossier de ce salon, fichier présent dans l'espace.

-- ============================================================
-- Espace de stockage « salons »
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('salons', 'salons', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp']);

-- Vrai si le fichier p_nom est dans le dossier d'un salon dont le compte
-- connecté est gérant. Le premier segment doit être un uuid : sinon faux
-- (pas d'erreur de conversion dans une policy).
create function private.gerant_du_dossier(p_nom text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_dossier text := split_part(p_nom, '/', 1);
begin
  if v_dossier !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  return private.a_le_role(v_dossier::uuid, 'gerant');
end;
$$;

revoke execute on function private.gerant_du_dossier(text) from public;
grant execute on function private.gerant_du_dossier(text) to authenticated;

-- La lecture publique passe par l'URL publique de l'espace (sans RLS). Ces
-- policies ne concernent que l'API Storage pour un compte connecté.
create policy "salons : gérant envoie la photo"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'salons' and private.gerant_du_dossier(name));

create policy "salons : gérant lit les fichiers de son salon"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'salons' and private.gerant_du_dossier(name));

create policy "salons : gérant supprime la photo"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'salons' and private.gerant_du_dossier(name));

-- ============================================================
-- salons.photo
-- ============================================================

alter table public.salons
  add column photo text;

comment on column public.salons.photo is
  'Chemin de la photo dans l''espace de stockage « salons » (#105) ; null : image par défaut.';

-- Enregistre (ou retire, p_chemin null) la photo de p_salon. Renvoie le
-- chemin précédent, que l'app supprime ensuite de l'espace de stockage.
-- Erreurs (code PTxxx : statut HTTP renvoyé par PostgREST) :
--   PT401 non connecté ;
--   PT403 pas gérant de ce salon ;
--   PT400 chemin hors du dossier du salon, ou fichier absent de l'espace.
create function public.definir_photo_salon(p_salon uuid, p_chemin text)
returns table (ancienne_photo text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ancienne text;
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if not private.a_le_role(p_salon, 'gerant') then
    raise exception 'Photo réservée au gérant du salon' using errcode = 'PT403';
  end if;

  if p_chemin is not null and (
       split_part(p_chemin, '/', 1) <> p_salon::text
       or not exists (
         select 1 from storage.objects o
          where o.bucket_id = 'salons' and o.name = p_chemin
       )
     ) then
    raise exception 'Photo introuvable' using errcode = 'PT400';
  end if;

  select s.photo into v_ancienne
    from public.salons s where s.id = p_salon for update;

  update public.salons s set photo = p_chemin where s.id = p_salon;

  return query select v_ancienne;
end;
$$;

revoke execute on function public.definir_photo_salon(uuid, text) from public, anon;
grant execute on function public.definir_photo_salon(uuid, text) to authenticated;
