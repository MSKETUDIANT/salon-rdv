-- Issue #145 (option A de Sparta) : le gérant invite un coiffeur par e-mail
-- depuis l'app pro, sans serveur supplémentaire.
--   1. public.invitations : invitations en attente (salon, e-mail, nom),
--      lisibles par le gérant du salon seulement ; écrites uniquement par les
--      fonctions ci-dessous ;
--   2. inviter_coiffeur() : si un compte existe déjà avec cet e-mail, il
--      reçoit tout de suite le rôle coiffeur ; sinon l'invitation attend ;
--   3. handle_new_user() (déclencheur d'inscription) : à la création d'un
--      compte dont l'e-mail a une invitation en attente, rôle coiffeur donné
--      et invitation marquée acceptée ;
--   4. annuler_invitation() : le gérant retire une invitation en attente.
-- E-mails toujours comparés en minuscules, espaces retirés.

-- ============================================================
-- public.invitations
-- ============================================================

create table public.invitations (
  id          uuid primary key default gen_random_uuid(),
  salon_id    uuid not null references public.salons (id) on delete cascade,
  email       text not null,
  nom         text not null,
  invite_par  uuid references public.utilisateurs (id) on delete set null,
  created_at  timestamptz not null default now(),
  acceptee_le timestamptz,
  constraint invitations_email_format check (
    email = lower(btrim(email)) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  ),
  constraint invitations_nom_longueur check (char_length(btrim(nom)) between 1 and 80)
);

comment on table public.invitations is
  'Invitations de coiffeurs par le gérant (#145) ; acceptee_le rempli à la création du compte.';

-- Une seule invitation en attente par e-mail et par salon.
create unique index invitations_en_attente
  on public.invitations (salon_id, email)
  where acceptee_le is null;

alter table public.invitations enable row level security;

-- Lecture : le gérant du salon. Aucune policy d'écriture : seules les
-- fonctions security definer ci-dessous écrivent.
create policy "invitations : le gérant lit celles de son salon"
  on public.invitations for select
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

-- ============================================================
-- inviter_coiffeur
-- ============================================================

-- Le gérant de p_salon invite un coiffeur. Résultat : 'ajoute' si un compte
-- existait déjà avec cet e-mail (rôle coiffeur donné tout de suite),
-- 'invite' sinon (invitation en attente ; réinviter met le nom à jour).
-- Erreurs : PT401 non connecté ; PT403 pas gérant de ce salon ; PT400 e-mail
-- ou nom invalide ; PT409 déjà coiffeur de ce salon.
create function public.inviter_coiffeur(p_salon uuid, p_email text, p_nom text)
returns table (resultat text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email  text := lower(btrim(coalesce(p_email, '')));
  v_nom    text := regexp_replace(btrim(coalesce(p_nom, '')), '\s+', ' ', 'g');
  v_compte uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if not private.a_le_role(p_salon, 'gerant') then
    raise exception 'Invitation réservée au gérant du salon' using errcode = 'PT403';
  end if;

  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'Adresse e-mail invalide' using errcode = 'PT400';
  end if;

  if char_length(v_nom) not between 1 and 80 then
    raise exception 'Nom invalide' using errcode = 'PT400';
  end if;

  select u.id into v_compte
    from public.utilisateurs u
   where lower(u.email) = v_email;

  if v_compte is not null then
    if exists (
      select 1 from public.roles_utilisateur
       where utilisateur_id = v_compte and salon_id = p_salon and role = 'coiffeur'
    ) then
      raise exception 'Déjà dans l''équipe' using errcode = 'PT409';
    end if;

    insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
    values (v_compte, p_salon, 'coiffeur');

    return query select 'ajoute'::text;
    return;
  end if;

  insert into public.invitations (salon_id, email, nom, invite_par)
  values (p_salon, v_email, v_nom, (select auth.uid()))
  on conflict (salon_id, email) where acceptee_le is null
  do update set nom = excluded.nom, invite_par = excluded.invite_par, created_at = now();

  return query select 'invite'::text;
end;
$$;

revoke execute on function public.inviter_coiffeur(uuid, text, text) from public, anon;
grant execute on function public.inviter_coiffeur(uuid, text, text) to authenticated;

-- ============================================================
-- annuler_invitation
-- ============================================================

-- Le gérant du salon de l'invitation la retire, tant qu'elle est en attente.
-- Erreurs : PT401 non connecté ; PT404 introuvable, déjà acceptée ou d'un
-- autre salon (sans dire laquelle).
create function public.annuler_invitation(p_invitation uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  delete from public.invitations i
   where i.id = p_invitation
     and i.acceptee_le is null
     and private.a_le_role(i.salon_id, 'gerant');

  if not found then
    raise exception 'Invitation introuvable' using errcode = 'PT404';
  end if;
end;
$$;

revoke execute on function public.annuler_invitation(uuid) from public, anon;
grant execute on function public.annuler_invitation(uuid) to authenticated;

-- ============================================================
-- Inscription : invitation acceptée
-- ============================================================

-- Même déclencheur qu'avant (#2 : ligne utilisateurs, rôle client si un seul
-- salon), plus : chaque invitation en attente pour cet e-mail donne le rôle
-- coiffeur dans son salon et passe acceptée. Le nom saisi par le gérant sert
-- si le compte n'en apporte pas.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta_salon text := new.raw_user_meta_data ->> 'salon_id';
  v_salon      uuid;
  v_email      text := lower(btrim(coalesce(new.email, '')));
  v_invitation record;
begin
  insert into public.utilisateurs (id, nom, email, telephone)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'nom'), ''),
      (select i.nom from public.invitations i
        where i.email = v_email and i.acceptee_le is null
        order by i.created_at desc limit 1),
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

  for v_invitation in
    select i.id, i.salon_id from public.invitations i
     where i.email = v_email and i.acceptee_le is null
  loop
    insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
    values (new.id, v_invitation.salon_id, 'coiffeur')
    on conflict do nothing;

    update public.invitations set acceptee_le = now() where id = v_invitation.id;
  end loop;

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
