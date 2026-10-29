-- Issue #103 : rendez-vous pour un client de passage, créé depuis l'app pro.
-- Choix de Sparta : 1A, une fiche client sans compte (nom, téléphone
-- facultatif ; utilisateurs.email est nullable), retrouvée par son téléphone
-- s'il revient ; 2A, le gérant pour n'importe quel coiffeur du salon, le
-- coiffeur pour lui seul. Mêmes contrôles que reserver() (créneau proposé
-- par creneaux_disponibles, verrou par coiffeur de #70, contrainte
-- d'exclusion en dernier rempart).

-- ============================================================
-- Fiches sans compte (option B2 de Sparta)
-- ============================================================
-- utilisateurs.id n'est plus obligatoirement un compte de connexion : une
-- fiche de client de passage reçoit un identifiant généré. Les comptes gardent
-- id = auth.users.id (déclencheur on_auth_user_created, inchangé).
-- RLS relue : « lecture / modification de sa ligne » exigent id = auth.uid()
-- (personne ne se connecte avec une fiche de passage) ; coiffeur et gérant
-- lisent ces fiches comme celles des autres clients de leurs rendez-vous.
-- Limite connue : si un jour le site connecte par téléphone (new.phone), un
-- compte au même numéro qu'une fiche de passage serait refusé (téléphone
-- unique) ; aujourd'hui la connexion se fait par e-mail.
alter table public.utilisateurs
  alter column id set default gen_random_uuid();
alter table public.utilisateurs
  drop constraint utilisateurs_id_fkey;

-- Remplace la suppression en cascade du lien retiré : supprimer un compte
-- supprime toujours sa fiche.
create function private.supprimer_fiche_du_compte()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.utilisateurs where id = old.id;
  return old;
end;
$$;

create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute function private.supprimer_fiche_du_compte();

create function public.reserver_pour_client(
  p_nom text,
  p_telephone text,
  p_prestation uuid,
  p_debut timestamptz,
  p_coiffeur uuid default null
)
returns table (id uuid, coiffeur_id uuid, debut timestamptz, fin timestamptz)
language plpgsql
security definer
set search_path = ''
set lock_timeout = '3s'
as $$
declare
  v_pro       uuid := (select auth.uid());
  v_salon     uuid;
  v_fuseau    text;
  v_duree     interval;
  v_jour      date;
  v_gerant    boolean;
  v_nom       text := nullif(btrim(p_nom), '');
  v_telephone text := nullif(btrim(p_telephone), '');
  v_client    uuid;
  v_candidats uuid[];
  v_candidat  uuid;
  v_id        uuid;
begin
  if v_pro is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;
  if v_nom is null then
    raise exception 'Nom du client requis' using errcode = 'PT400';
  end if;

  select p.salon_id, s.fuseau_horaire, make_interval(mins => p.duree_minutes)
    into v_salon, v_fuseau, v_duree
    from public.prestations p
    join public.salons s on s.id = p.salon_id
   where p.id = p_prestation
     and p.active;
  if v_salon is null then
    raise exception 'Prestation introuvable' using errcode = 'PT404';
  end if;

  -- Gérant : tout coiffeur du salon ; coiffeur : lui seul.
  v_gerant := exists (
    select 1 from public.roles_utilisateur r
     where r.utilisateur_id = v_pro and r.salon_id = v_salon and r.role = 'gerant'
  );
  if not v_gerant then
    if not exists (
      select 1 from public.roles_utilisateur r
       where r.utilisateur_id = v_pro and r.salon_id = v_salon and r.role = 'coiffeur'
    ) then
      raise exception 'Réservé à l''équipe du salon' using errcode = 'PT403';
    end if;
    if p_coiffeur is not null and p_coiffeur <> v_pro then
      raise exception 'Un coiffeur ne réserve que pour lui' using errcode = 'PT403';
    end if;
    p_coiffeur := v_pro;
  end if;

  -- Fiche du client : retrouvée par téléphone, sinon créée sans compte.
  if v_telephone is not null then
    select u.id into v_client from public.utilisateurs u where u.telephone = v_telephone;
  end if;
  if v_client is null then
    insert into public.utilisateurs (nom, telephone)
    values (v_nom, v_telephone)
    returning utilisateurs.id into v_client;
  end if;
  insert into public.roles_utilisateur (utilisateur_id, salon_id, role)
  values (v_client, v_salon, 'client')
  on conflict do nothing;

  v_jour := (p_debut at time zone v_fuseau)::date;

  select array_agg(c.coiffeur_id order by (
           select count(*) from public.reservations r
            where r.coiffeur_id = c.coiffeur_id
              and r.statut <> 'annulee'
              and (r.debut at time zone v_fuseau)::date = v_jour
         ), c.coiffeur_id)
    into v_candidats
    from public.creneaux_disponibles(p_prestation, v_jour, v_jour, p_coiffeur) as c
   where c.debut = p_debut;

  -- Même verrou que reserver() (#70) : dans l'ordre des identifiants.
  perform pg_advisory_xact_lock(hashtextextended('reservations:' || c::text, 0))
     from unnest(v_candidats) as c
    order by c;

  foreach v_candidat in array coalesce(v_candidats, '{}') loop
    begin
      insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
      values (v_salon, v_client, v_candidat, p_prestation, p_debut, p_debut + v_duree)
      returning reservations.id into v_id;

      return query select v_id, v_candidat, p_debut, p_debut + v_duree;
      return;
    exception when exclusion_violation then
      null;
    end;
  end loop;

  raise exception 'Ce créneau n''est plus disponible' using errcode = 'PT409';
end;
$$;

revoke execute on function public.reserver_pour_client(text, text, uuid, timestamptz, uuid) from public, anon;
grant execute on function public.reserver_pour_client(text, text, uuid, timestamptz, uuid) to authenticated;
