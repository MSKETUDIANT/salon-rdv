-- Issue #110 : la règle « annulable » écrite une seule fois.
-- Elle était écrite deux fois, dans mes_reservations() (colonne annulable,
-- qui affiche « Annuler » sur le site) et dans annuler_reservation() (refus
-- PT409) : deux copies qui devaient rester identiques (docs/dette-technique.md).
-- Les deux fonctions appellent désormais private.reservation_annulable().
-- Comportement inchangé : confirmée et pas encore commencée.

-- ============================================================
-- private.reservation_annulable
-- ============================================================

-- stable : dépend de now(). Schéma private : appelée seulement par les
-- fonctions security definer ci-dessous, pas par les clients.
create function private.reservation_annulable(
  p_statut public.statut_reservation,
  p_debut  timestamptz
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_statut = 'confirmee' and p_debut > now();
$$;

revoke execute on function private.reservation_annulable(public.statut_reservation, timestamptz) from public;

-- ============================================================
-- mes_reservations : colonne annulable par la règle commune
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
         private.reservation_annulable(r.statut, r.debut)
    from public.reservations r
    join public.prestations p on p.id = r.prestation_id
    join public.utilisateurs u on u.id = r.coiffeur_id
   where r.client_id = (select auth.uid())
     and r.salon_id = p_salon
   order by r.debut, r.id;
$$;

-- ============================================================
-- annuler_reservation : refus par la règle commune
-- ============================================================

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
begin
  if v_client is null then
    raise exception 'Connexion requise pour annuler' using errcode = 'PT401';
  end if;

  -- Verrou : deux annulations simultanées ne se croisent pas.
  select r.statut, r.debut into v_statut, v_debut
    from public.reservations r
   where r.id = p_reservation
     and r.client_id = v_client
     for update;
  if not found then
    raise exception 'Réservation introuvable' using errcode = 'PT404';
  end if;

  if not private.reservation_annulable(v_statut, v_debut) then
    raise exception 'Cette réservation ne peut plus être annulée' using errcode = 'PT409';
  end if;

  update public.reservations r
     set statut = 'annulee'
   where r.id = p_reservation;

  return query select p_reservation, 'annulee'::public.statut_reservation;
end;
$$;
