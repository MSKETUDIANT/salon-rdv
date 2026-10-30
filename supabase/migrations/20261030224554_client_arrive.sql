-- Issue #102 : « Client arrivé » (options 1A et 2a de Sparta, 2026-10-30).
-- L'arrivée est une heure sur le rendez-vous, pas un nouveau statut : le
-- statut reste « confirmee », donc rien ne change pour le site client, la
-- contrainte d'exclusion, l'annulation, la clôture ni l'historique.
--
-- Règles :
--   1. arrivée marquée par le coiffeur du rendez-vous ou par le gérant du
--      salon, seulement par marquer_arrivee() (aucun droit d'écriture direct
--      sur la colonne) ;
--   2. seulement sur un rendez-vous confirmé du jour (date du salon) ;
--      l'heure est celle du serveur ;
--   3. l'arrivée s'annule (retour à null) tant que le rendez-vous est
--      confirmé ;
--   4. un client arrivé ne peut pas être marqué absent : annuler d'abord son
--      arrivée.

-- ============================================================
-- reservations.arrive_le
-- ============================================================

alter table public.reservations
  add column arrive_le timestamptz;

comment on column public.reservations.arrive_le is
  'Heure d''arrivée du client au salon (#102) ; null : pas encore arrivé.';

-- ============================================================
-- marquer_arrivee
-- ============================================================

-- Marque (p_arrive = true) ou annule (false) l'arrivée du client de
-- p_reservation. Renvoie la nouvelle heure d'arrivée (null si annulée).
-- security definer : le coiffeur n'a de droit d'écriture que sur le statut.
-- Erreurs (code PTxxx : statut HTTP renvoyé par PostgREST) :
--   PT401 non connecté ;
--   PT404 rendez-vous inconnu, ou ni le sien (coiffeur) ni de son salon
--         (gérant), sans dire lequel ;
--   PT409 rendez-vous pas confirmé (terminé, absent, annulé), ou arrivée
--         marquée un autre jour que celui du rendez-vous.
create function public.marquer_arrivee(
  p_reservation uuid,
  p_arrive boolean default true
)
returns table (id uuid, arrive_le timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_moi    uuid := (select auth.uid());
  v_r      public.reservations%rowtype;
  v_fuseau text;
  v_arrive timestamptz;
begin
  if v_moi is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  -- Verrou : une arrivée et une clôture simultanées ne se croisent pas.
  select r.* into v_r
    from public.reservations r
   where r.id = p_reservation
     for update;
  if not found
     or not (
       exists (
         select 1 from public.roles_utilisateur ru
          where ru.utilisateur_id = v_moi and ru.salon_id = v_r.salon_id
            and ru.role = 'gerant'
       )
       or (v_r.coiffeur_id = v_moi and exists (
         select 1 from public.roles_utilisateur ru
          where ru.utilisateur_id = v_moi and ru.salon_id = v_r.salon_id
            and ru.role = 'coiffeur'
       ))
     ) then
    raise exception 'Rendez-vous introuvable' using errcode = 'PT404';
  end if;

  if v_r.statut <> 'confirmee' then
    raise exception 'Rendez-vous déjà clôturé ou annulé' using errcode = 'PT409';
  end if;

  if p_arrive then
    select s.fuseau_horaire into v_fuseau
      from public.salons s where s.id = v_r.salon_id;
    if (v_r.debut at time zone v_fuseau)::date <> (now() at time zone v_fuseau)::date then
      raise exception 'Arrivée possible seulement le jour du rendez-vous' using errcode = 'PT409';
    end if;
    -- Déjà arrivé : l'heure de la première arrivée est gardée.
    v_arrive := coalesce(v_r.arrive_le, now());
  end if;

  update public.reservations r
     set arrive_le = v_arrive
   where r.id = p_reservation;

  return query select p_reservation, v_arrive;
end;
$$;

-- Supabase accorde EXECUTE à anon par défaut sur les nouvelles fonctions.
revoke execute on function public.marquer_arrivee(uuid, boolean) from public, anon;
grant execute on function public.marquer_arrivee(uuid, boolean) to authenticated;

-- ============================================================
-- Transitions : un client arrivé n'est pas absent
-- ============================================================

-- Mêmes règles que 20261025153145_cloture_encaissement.sql, plus la règle 4.
create or replace function public.verifier_transition_statut()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.statut is distinct from old.statut
     and not (old.statut = 'confirmee'
              and new.statut in ('annulee', 'terminee', 'absent')) then
    raise exception 'Transition de statut interdite : % -> %', old.statut, new.statut
      using errcode = '23514';
  end if;

  if new.statut is distinct from old.statut
     and new.statut in ('terminee', 'absent')
     and old.debut > now() then
    raise exception 'Rendez-vous pas encore commencé' using errcode = 'PT409';
  end if;

  if new.statut is distinct from old.statut
     and new.statut = 'absent'
     and old.arrive_le is not null then
    raise exception 'Client arrivé : annulez d''abord son arrivée' using errcode = 'PT409';
  end if;

  return new;
end;
$$;

-- ============================================================
-- planning : heure d'arrivée
-- ============================================================

-- Mêmes règles que dans 20261025153145_cloture_encaissement.sql ; colonne
-- ajoutée : arrive_le. Le type de retour change : drop puis create.
drop function public.planning(uuid, date, date, uuid);

create function public.planning(
  p_salon uuid,
  p_du date,
  p_au date,
  p_coiffeur uuid default null
)
returns table (
  id               uuid,
  coiffeur_id      uuid,
  debut            timestamptz,
  fin              timestamptz,
  statut           public.statut_reservation,
  prestation       varchar,
  duree_minutes    integer,
  client_nom       varchar,
  client_telephone varchar,
  prix             numeric,
  montant_encaisse numeric,
  arrive_le        timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_moi    uuid := (select auth.uid());
  v_fuseau text;
  v_gerant boolean;
  v_cible  uuid := p_coiffeur;
begin
  if v_moi is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if p_du is null or p_au is null or p_au < p_du or p_au - p_du > 30 then
    raise exception 'Période de 1 à 31 jours' using errcode = 'PT400';
  end if;

  v_gerant := exists (
    select 1 from public.roles_utilisateur r
     where r.utilisateur_id = v_moi and r.salon_id = p_salon and r.role = 'gerant'
  );

  if not v_gerant then
    if not exists (
      select 1 from public.roles_utilisateur r
       where r.utilisateur_id = v_moi and r.salon_id = p_salon and r.role = 'coiffeur'
    ) then
      raise exception 'Planning réservé à l''équipe du salon' using errcode = 'PT403';
    end if;
    if v_cible is not null and v_cible <> v_moi then
      raise exception 'Un coiffeur ne voit que son planning' using errcode = 'PT403';
    end if;
    v_cible := v_moi;
  end if;

  select s.fuseau_horaire into v_fuseau from public.salons s where s.id = p_salon;

  return query
    select r.id, r.coiffeur_id, r.debut, r.fin, r.statut,
           p.nom, p.duree_minutes, u.nom, u.telephone,
           p.prix, case when v_gerant then e.montant end,
           r.arrive_le
      from public.reservations r
      join public.prestations p on p.id = r.prestation_id
      join public.utilisateurs u on u.id = r.client_id
      left join public.encaissements e on e.reservation_id = r.id
     where r.salon_id = p_salon
       and r.statut <> 'annulee'
       and (v_cible is null or r.coiffeur_id = v_cible)
       and (r.debut at time zone v_fuseau)::date between p_du and p_au
     order by r.debut, r.coiffeur_id;
end;
$$;

revoke execute on function public.planning(uuid, date, date, uuid) from public, anon;
grant execute on function public.planning(uuid, date, date, uuid) to authenticated;
