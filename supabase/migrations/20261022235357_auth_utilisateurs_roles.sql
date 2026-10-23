-- Issue #2 : authentification et rôles par salon.
-- Une ligne utilisateurs par compte auth, rôle client à l'inscription,
-- rôles attribués ensuite par un gérant du salon.

-- ============================================================
-- utilisateurs.id = auth.users.id
-- ============================================================

alter table public.utilisateurs
  alter column id drop default,
  add constraint utilisateurs_id_fkey
    foreign key (id) references auth.users (id) on delete cascade;

-- Rôles, compétences, horaires et absences n'ont pas de valeur historique :
-- supprimés avec le compte. Sans ça, aucun compte n'est supprimable (chaque
-- inscrit a un rôle). Réservations et encaissements restent bloquants : ils
-- protègent l'historique.
alter table public.roles_utilisateur
  drop constraint roles_utilisateur_utilisateur_id_fkey,
  add constraint roles_utilisateur_utilisateur_id_fkey
    foreign key (utilisateur_id) references public.utilisateurs (id) on delete cascade;

alter table public.competences
  drop constraint competences_coiffeur_id_fkey,
  add constraint competences_coiffeur_id_fkey
    foreign key (coiffeur_id) references public.utilisateurs (id) on delete cascade;

alter table public.horaires
  drop constraint horaires_coiffeur_id_fkey,
  add constraint horaires_coiffeur_id_fkey
    foreign key (coiffeur_id) references public.utilisateurs (id) on delete cascade;

alter table public.absences
  drop constraint absences_coiffeur_id_fkey,
  add constraint absences_coiffeur_id_fkey
    foreign key (coiffeur_id) references public.utilisateurs (id) on delete cascade;

-- ============================================================
-- Inscription : création de la ligne utilisateurs + rôle client
-- ============================================================

-- Le salon vient des métadonnées d'inscription (salon_id). S'il est absent et
-- qu'il n'existe qu'un seul salon, on prend celui-là. Sinon : pas de rôle.
-- Un rôle passé dans les métadonnées est toujours ignoré.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta_salon text := new.raw_user_meta_data ->> 'salon_id';
  v_salon      uuid;
begin
  insert into public.utilisateurs (id, nom, email, telephone)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'nom'), ''),
      nullif(split_part(new.email, '@', 1), ''),
      'Sans nom'
    ),
    new.email,
    nullif(new.phone, '')
  );

  if v_meta_salon is null then
    if (select count(*) from public.salons) = 1 then
      select id into v_salon from public.salons;
    end if;
  elsif v_meta_salon ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    select id into v_salon from public.salons where id = v_meta_salon::uuid;
  end if;

  if v_salon is not null then
    insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
    values (new.id, v_salon, 'client');
  end if;

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- Attribution d'un rôle par un gérant du salon
-- ============================================================

-- Seul chemin d'écriture dans roles_utilisateur pour les utilisateurs
-- (RLS active sans policy). Attribuer deux fois le même rôle ne fait rien.
create function public.attribuer_role(p_utilisateur uuid, p_salon uuid, p_role public.role)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
      from public.roles_utilisateur
     where utilisateur_id = (select auth.uid())
       and salon_id = p_salon
       and role = 'gerant'
  ) then
    raise exception 'Seul un gérant du salon peut attribuer un rôle'
      using errcode = '42501';
  end if;

  insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
  values (p_utilisateur, p_salon, p_role)
  on conflict do nothing;
end;
$$;

revoke execute on function public.attribuer_role(uuid, uuid, public.role) from public, anon;
grant execute on function public.attribuer_role(uuid, uuid, public.role) to authenticated;
