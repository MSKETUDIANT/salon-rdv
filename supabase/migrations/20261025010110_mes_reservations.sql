-- Issue #7 : consulter et annuler sa réservation (BF-C6), un client ne voit
-- et n'annule que les siennes (BNF-3).
-- mes_reservations() et annuler_reservation() deviennent les seuls chemins du
-- client, comme reserver() pour la création (#6).

-- ============================================================
-- Plus de modification directe par les clients
-- ============================================================

-- La policy de l'issue #3 laissait le client annuler une réservation passée
-- restée « confirmée ». annuler_reservation() refuse ce cas ; la
-- modification directe n'a plus lieu d'être. Coiffeur et gérant gardent leurs
-- policies (app pro).
drop policy "reservations : client modifie les siennes" on public.reservations;

-- ============================================================
-- mes_reservations
-- ============================================================

-- Réservations du client connecté dans p_salon, la plus ancienne d'abord.
-- security definer : le client ne lit ni les prestations désactivées ni le
-- nom des coiffeurs (utilisateurs) ; une réservation passée doit pourtant
-- rester lisible. Prix : celui de la prestation aujourd'hui (la réservation
-- ne le fige pas).
-- annulable : confirmée et pas encore commencée (même règle que
-- annuler_reservation).
create function public.mes_reservations(p_salon uuid)
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
         r.statut = 'confirmee' and r.debut > now()
    from public.reservations r
    join public.prestations p on p.id = r.prestation_id
    join public.utilisateurs u on u.id = r.coiffeur_id
   where r.client_id = (select auth.uid())
     and r.salon_id = p_salon
   order by r.debut, r.id;
$$;

revoke execute on function public.mes_reservations(uuid) from public, anon;
grant execute on function public.mes_reservations(uuid) to authenticated;

-- ============================================================
-- annuler_reservation
-- ============================================================

-- Annule p_reservation du client connecté : changement de statut, jamais de
-- suppression. Le créneau redevient disponible (creneaux_disponibles et la
-- contrainte d'exclusion ignorent les réservations annulées).
-- Erreurs (code PTxxx : statut HTTP renvoyé par PostgREST) :
--   PT401 non connecté ;
--   PT404 réservation inconnue ou d'un autre client (sans dire laquelle) ;
--   PT409 plus annulable : déjà commencée ou passée, terminée, annulée...
create function public.annuler_reservation(p_reservation uuid)
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

  if v_statut <> 'confirmee' or v_debut <= now() then
    raise exception 'Cette réservation ne peut plus être annulée' using errcode = 'PT409';
  end if;

  update public.reservations r
     set statut = 'annulee'
   where r.id = p_reservation;

  return query select p_reservation, 'annulee'::public.statut_reservation;
end;
$$;

revoke execute on function public.annuler_reservation(uuid) from public, anon;
grant execute on function public.annuler_reservation(uuid) to authenticated;
