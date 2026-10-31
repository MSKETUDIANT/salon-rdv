-- Issue #118 : délai minimum d'annulation, réglable par le gérant (options 1A
-- et 2a de Sparta, 2026-10-31). Par défaut 0 : comportement inchangé (un
-- client annule jusqu'au début du rendez-vous) tant que le gérant n'a rien
-- choisi.
--
-- Règles :
--   1. salons.delai_annulation_minutes : entre 0 et 7 jours (10 080 min) ;
--   2. la règle « annulable » reste écrite une seule fois
--      (private.reservation_annulable, #110), le délai en plus : confirmée et
--      début à plus de « délai » de maintenant ;
--   3. le délai se change seulement par definir_delai_annulation(), par le
--      gérant du salon (aucun droit d'écriture sur salons).

-- ============================================================
-- salons.delai_annulation_minutes
-- ============================================================

alter table public.salons
  add column delai_annulation_minutes integer not null default 0,
  add constraint salons_delai_annulation_borne
    check (delai_annulation_minutes between 0 and 10080);

comment on column public.salons.delai_annulation_minutes is
  'Délai minimum d''annulation en minutes (#118) ; 0 : jusqu''au début du rendez-vous.';

-- ============================================================
-- Règle « annulable » : le délai en plus
-- ============================================================

-- Nouvelle signature (troisième paramètre, 0 par défaut) : drop puis create.
-- PostgreSQL ne lie pas une fonction à celles qu'elle appelle ; les deux
-- fonctions qui l'utilisent sont recréées juste après.
drop function private.reservation_annulable(public.statut_reservation, timestamptz);

create function private.reservation_annulable(
  p_statut        public.statut_reservation,
  p_debut         timestamptz,
  p_delai_minutes integer default 0
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_statut = 'confirmee'
     and p_debut > now() + make_interval(mins => coalesce(p_delai_minutes, 0));
$$;

revoke execute on function private.reservation_annulable(public.statut_reservation, timestamptz, integer) from public;

-- ============================================================
-- mes_reservations et annuler_reservation : délai du salon
-- ============================================================

create or replace function public.mes_reservations(p_salon uuid)
returns table (
  id            uuid,
  prestation    varchar,
  prix          numeric,
  duree_minutes integer,
  coiffeur      varchar,
  debut         timestamptz,
  fin           timestamptz,
  statut        public.statut_reservation,
  annulable     boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, p.nom, p.prix, p.duree_minutes, u.nom, r.debut, r.fin, r.statut,
         private.reservation_annulable(r.statut, r.debut, s.delai_annulation_minutes)
    from public.reservations r
    join public.prestations p on p.id = r.prestation_id
    join public.utilisateurs u on u.id = r.coiffeur_id
    join public.salons s on s.id = r.salon_id
   where r.client_id = (select auth.uid())
     and r.salon_id = p_salon
   order by r.debut, r.id;
$$;

create or replace function public.annuler_reservation(p_reservation uuid)
returns table (id uuid, statut public.statut_reservation)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_client uuid := (select auth.uid());
  v_statut public.statut_reservation;
  v_debut  timestamptz;
  v_delai  integer;
begin
  if v_client is null then
    raise exception 'Connexion requise pour annuler' using errcode = 'PT401';
  end if;

  -- Verrou : deux annulations simultanées ne se croisent pas.
  select r.statut, r.debut, s.delai_annulation_minutes
    into v_statut, v_debut, v_delai
    from public.reservations r
    join public.salons s on s.id = r.salon_id
   where r.id = p_reservation
     and r.client_id = v_client
     for update of r;
  if not found then
    raise exception 'Réservation introuvable' using errcode = 'PT404';
  end if;

  if not private.reservation_annulable(v_statut, v_debut, v_delai) then
    raise exception 'Cette réservation ne peut plus être annulée' using errcode = 'PT409';
  end if;

  update public.reservations r
     set statut = 'annulee'
   where r.id = p_reservation;

  return query select p_reservation, 'annulee'::public.statut_reservation;
end;
$$;

-- ============================================================
-- definir_delai_annulation
-- ============================================================

-- Le gérant de p_salon règle le délai (en minutes, 0 à 10 080).
-- Erreurs : PT401 non connecté ; PT403 pas gérant de ce salon ; PT400 délai
-- hors bornes.
create function public.definir_delai_annulation(p_salon uuid, p_minutes integer)
returns table (delai_annulation_minutes integer)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if not private.a_le_role(p_salon, 'gerant') then
    raise exception 'Réglage réservé au gérant du salon' using errcode = 'PT403';
  end if;

  if p_minutes is null or p_minutes < 0 or p_minutes > 10080 then
    raise exception 'Délai de 0 à 7 jours' using errcode = 'PT400';
  end if;

  update public.salons s
     set delai_annulation_minutes = p_minutes
   where s.id = p_salon;

  return query select p_minutes;
end;
$$;

revoke execute on function public.definir_delai_annulation(uuid, integer) from public, anon;
grant execute on function public.definir_delai_annulation(uuid, integer) to authenticated;
