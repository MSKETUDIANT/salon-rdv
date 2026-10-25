-- Issue #10 : plannings de l'app pro (BF-K1, BF-K2, BF-G5).
--
-- Règles :
--   1. un coiffeur ne lit que ses propres rendez-vous ; le gérant lit ceux de
--      son salon ;
--   2. des clients, le coiffeur ne voit que le nom et le téléphone (BF-K2,
--      issue #10), jamais l'e-mail ni leurs autres réservations.
--
-- La lecture directe de reservations respecte déjà la règle 1 (policies de
-- #3). Pour la règle 2, l'accès du coiffeur à la table utilisateurs est
-- retiré : le planning passe par la fonction planning(), qui ne renvoie que
-- les colonnes utiles.

-- ============================================================
-- utilisateurs : le coiffeur ne lit plus la ligne de ses clients
-- ============================================================

-- La policy de #3 lui donnait la ligne entière (e-mail compris), y compris
-- après la perte de son rôle de coiffeur dans le salon.
drop policy "utilisateurs : coiffeur lit ses clients" on public.utilisateurs;

-- ============================================================
-- planning
-- ============================================================

-- Rendez-vous non annulés de p_salon dont le début tombe entre p_du et p_au
-- inclus (dates du salon, 31 jours au plus), avec le nom et le téléphone du
-- client. p_coiffeur null : tous ceux que l'appelant peut voir.
--   gérant du salon : tous les coiffeurs, ou p_coiffeur ;
--   coiffeur du salon (non gérant) : les siens seulement ;
--     p_coiffeur d'un collègue → PT403 ;
--   autre compte (client, autre salon) → PT403 ; non connecté → PT401.
-- security definer : lit utilisateurs sans la rouvrir au coiffeur, et ne
-- renvoie ni e-mail, ni identifiant du client.
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
  client_telephone varchar
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
           p.nom, p.duree_minutes, u.nom, u.telephone
      from public.reservations r
      join public.prestations p on p.id = r.prestation_id
      join public.utilisateurs u on u.id = r.client_id
     where r.salon_id = p_salon
       and r.statut <> 'annulee'
       and (v_cible is null or r.coiffeur_id = v_cible)
       and (r.debut at time zone v_fuseau)::date between p_du and least(p_au, p_du + 30)
     order by r.debut, r.coiffeur_id;
end;
$$;

revoke execute on function public.planning(uuid, date, date, uuid) from public, anon;
grant execute on function public.planning(uuid, date, date, uuid) to authenticated;
