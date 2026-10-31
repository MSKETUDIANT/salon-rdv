-- Issue #148 (option de Sparta : e-mail automatique et lien unique) : le
-- compte du coiffeur invité est créé par l'invitation (e-mail envoyé par la
-- fonction Edge inviter-coiffeur), puis confirmé quand il saisit le code reçu
-- dans l'app.
--   1. private.accepter_invitations() : rôle coiffeur dans chaque salon qui a
--      invité cette adresse, invitation marquée acceptée ;
--   2. handle_new_user() (création du compte) : invitations acceptées
--      seulement si l'adresse est déjà confirmée ; sinon elles attendent ;
--   3. on_auth_user_confirmed (adresse confirmée par le code) : invitations
--      acceptées à ce moment-là ;
--   4. inviter_coiffeur() : un compte dont l'adresse n'est pas confirmée
--      (invitation envoyée, jamais ouverte) reste une invitation en attente :
--      réinviter la renvoie au lieu d'ajouter le coiffeur.

-- ============================================================
-- private.accepter_invitations
-- ============================================================

create function private.accepter_invitations(p_utilisateur uuid, p_email text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitation record;
begin
  for v_invitation in
    select i.id, i.salon_id from public.invitations i
     where i.email = lower(btrim(coalesce(p_email, ''))) and i.acceptee_le is null
  loop
    insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
    values (p_utilisateur, v_invitation.salon_id, 'coiffeur')
    on conflict do nothing;

    update public.invitations set acceptee_le = now() where id = v_invitation.id;
  end loop;
end;
$$;

revoke execute on function private.accepter_invitations(uuid, text) from public, anon, authenticated;

-- ============================================================
-- Création du compte
-- ============================================================

-- Comme #145 (ligne utilisateurs, nom de l'invitation à défaut, rôle client
-- si un seul salon), mais les invitations ne sont acceptées que pour une
-- adresse déjà confirmée.
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

  if new.email_confirmed_at is not null then
    perform private.accepter_invitations(new.id, new.email);
  end if;

  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- ============================================================
-- Adresse confirmée
-- ============================================================

create function public.handle_user_confirmed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.accepter_invitations(new.id, new.email);
  return new;
end;
$$;

revoke execute on function public.handle_user_confirmed() from public, anon, authenticated;

create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.handle_user_confirmed();

-- ============================================================
-- inviter_coiffeur
-- ============================================================

-- Comme #145 ; seule la recherche du compte change : un compte non confirmé
-- ne compte pas comme existant.
create or replace function public.inviter_coiffeur(p_salon uuid, p_email text, p_nom text)
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
    join auth.users a on a.id = u.id
   where lower(u.email) = v_email
     and a.email_confirmed_at is not null;

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
