-- Issue #6 : réserver un créneau (BF-C5), zéro double réservation (BNF-1).
-- La fonction reserver() devient le seul chemin pour créer une réservation :
-- elle revérifie la disponibilité au moment d'enregistrer (même règle que
-- creneaux_disponibles, #5). La contrainte reservations_sans_chevauchement
-- reste le dernier rempart contre deux validations simultanées.

-- ============================================================
-- Plus d'insertion directe par les clients
-- ============================================================

-- La policy de l'issue #3 ne contrôlait que l'identité et le salon (horaires,
-- absences, durée et compétence : docs/dette-technique.md). reserver() les
-- contrôle tous ; l'insertion directe n'a plus lieu d'être.
drop policy "reservations : client réserve pour lui" on public.reservations;
revoke insert on public.reservations from authenticated;

-- ============================================================
-- reserver
-- ============================================================

-- Réserve p_prestation à p_debut pour le client connecté, avec p_coiffeur ou,
-- s'il est null (« Peu importe »), un coiffeur libre et compétent : le moins
-- chargé ce jour-là, puis le premier par id.
-- Erreurs (code PTxxx : statut HTTP renvoyé par PostgREST) :
--   PT401 non connecté ; PT404 prestation inconnue ou inactive ;
--   PT403 compte non client du salon ;
--   PT409 créneau indisponible (hors horaires, pris, passé, coiffeur non
--         compétent...), y compris pris par une validation simultanée.
-- security definer : le client n'a plus le droit d'insérer lui-même.
create function public.reserver(
  p_prestation uuid,
  p_debut timestamptz,
  p_coiffeur uuid default null
)
returns table (id uuid, coiffeur_id uuid, debut timestamptz, fin timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_client   uuid := (select auth.uid());
  v_salon    uuid;
  v_fuseau   text;
  v_duree    interval;
  v_jour     date;
  v_candidat uuid;
  v_id       uuid;
begin
  if v_client is null then
    raise exception 'Connexion requise pour réserver' using errcode = 'PT401';
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

  if not exists (
    select 1 from public.roles_utilisateur r
     where r.utilisateur_id = v_client and r.salon_id = v_salon and r.role = 'client'
  ) then
    raise exception 'Ce compte n''est pas client de ce salon' using errcode = 'PT403';
  end if;

  v_jour := (p_debut at time zone v_fuseau)::date;

  for v_candidat in
    select c.coiffeur_id
      from public.creneaux_disponibles(p_prestation, v_jour, v_jour, p_coiffeur) as c
     where c.debut = p_debut
     order by (
       select count(*) from public.reservations r
        where r.coiffeur_id = c.coiffeur_id
          and r.statut <> 'annulee'
          and (r.debut at time zone v_fuseau)::date = v_jour
     ), c.coiffeur_id
  loop
    begin
      insert into public.reservations (salon_id, client_id, coiffeur_id, prestation_id, debut, fin)
      values (v_salon, v_client, v_candidat, p_prestation, p_debut, p_debut + v_duree)
      returning reservations.id into v_id;

      return query select v_id, v_candidat, p_debut, p_debut + v_duree;
      return;
    exception when exclusion_violation then
      -- Pris par une validation simultanée : coiffeur suivant, s'il y en a.
      null;
    end;
  end loop;

  raise exception 'Ce créneau n''est plus disponible' using errcode = 'PT409';
end;
$$;

revoke execute on function public.reserver(uuid, timestamptz, uuid) from public, anon;
grant execute on function public.reserver(uuid, timestamptz, uuid) to authenticated;
