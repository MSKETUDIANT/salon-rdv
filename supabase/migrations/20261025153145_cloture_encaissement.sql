-- Issue #11 : clôture d'un rendez-vous, client absent, encaissement,
-- historique (BF-K3, BF-K4, BF-G4).
--
-- Règles :
--   1. « Terminé » et « Client absent » seulement sur un rendez-vous commencé
--      (debut <= now()), par son coiffeur ou par le gérant du salon (policies
--      de #3) ; transitions déjà contrôlées par le trigger de #3 ;
--   2. seul un rendez-vous terminé est encaissable, une seule fois (contrainte
--      unique de #1), par le gérant ; montant >= 0 (contrainte de #1) ;
--   3. le gérant ne corrige que le montant d'un encaissement (pas de trace des
--      corrections : docs/dette-technique.md) ;
--   4. historique (rendez-vous terminés et absents, encaissements) : gérant
--      seulement.

-- ============================================================
-- reservations : clôture seulement après le début
-- ============================================================

-- Remplace la fonction de #3 : mêmes transitions, plus la règle de temps.
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

  return new;
end;
$$;

-- ============================================================
-- encaissements
-- ============================================================

-- Seul un rendez-vous terminé est encaissable : dans la policy (API) et dans
-- un trigger (tous les chemins, message clair). Le trigger ne voit que ce que
-- l'appelant peut lire : une réservation invisible est laissée à la RLS.
create function public.verifier_encaissement()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_statut public.statut_reservation;
begin
  select r.statut into v_statut
    from public.reservations r where r.id = new.reservation_id;
  if found and v_statut <> 'terminee' then
    raise exception 'Seul un rendez-vous terminé est encaissable' using errcode = 'PT409';
  end if;
  return new;
end;
$$;

revoke execute on function public.verifier_encaissement() from public, anon, authenticated;

create trigger encaissements_rendez_vous_termine
  before insert or update of reservation_id on public.encaissements
  for each row execute function public.verifier_encaissement();

drop policy "encaissements : gérant enregistre" on public.encaissements;
create policy "encaissements : gérant enregistre"
  on public.encaissements for insert
  to authenticated
  with check (
    encaisse_par = (select auth.uid())
    and exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and r.statut = 'terminee'
         and private.a_le_role(r.salon_id, 'gerant')
    )
  );

-- Correction du montant par n'importe quel gérant du salon : encaisse_par
-- reste celui qui a encaissé (colonne non modifiable).
drop policy "encaissements : gérant modifie" on public.encaissements;
create policy "encaissements : gérant modifie"
  on public.encaissements for update
  to authenticated
  using (
    exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and private.a_le_role(r.salon_id, 'gerant')
    )
  )
  with check (
    exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and private.a_le_role(r.salon_id, 'gerant')
    )
  );

revoke insert, update on public.encaissements from authenticated;
grant insert (id, reservation_id, montant, encaisse_par) on public.encaissements to authenticated;
grant update (montant) on public.encaissements to authenticated;

-- ============================================================
-- planning : prix et montant encaissé
-- ============================================================

-- Mêmes règles que dans 20261025054311_planning.sql ; colonnes ajoutées :
-- prix de la prestation, montant encaissé (gérant seulement, null pour un
-- coiffeur). Le type de retour change : drop puis create.
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
  montant_encaisse numeric
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
           p.prix, case when v_gerant then e.montant end
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

-- Supabase accorde EXECUTE à anon par défaut sur les nouvelles fonctions.
revoke execute on function public.planning(uuid, date, date, uuid) from public, anon;
grant execute on function public.planning(uuid, date, date, uuid) to authenticated;

-- ============================================================
-- historique
-- ============================================================

-- Rendez-vous terminés et clients absents de p_salon dont le début tombe
-- entre p_du et p_au inclus (dates du salon, 31 jours au plus), avec
-- l'encaissement s'il existe. p_coiffeur null : tous les coiffeurs.
--   gérant du salon seulement ; autre compte → PT403 ; non connecté → PT401 ;
--   période absente, à l'envers ou de plus de 31 jours → PT400.
-- security definer : lit les noms (coiffeurs, clients) sans élargir la RLS
-- de utilisateurs.
create function public.historique(
  p_salon uuid,
  p_du date,
  p_au date,
  p_coiffeur uuid default null
)
returns table (
  id            uuid,
  coiffeur_id   uuid,
  coiffeur      varchar,
  debut         timestamptz,
  fin           timestamptz,
  statut        public.statut_reservation,
  prestation    varchar,
  prix          numeric,
  client_nom    varchar,
  montant       numeric,
  encaisse_le   timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_moi    uuid := (select auth.uid());
  v_fuseau text;
begin
  if v_moi is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if p_du is null or p_au is null or p_au < p_du or p_au - p_du > 30 then
    raise exception 'Période de 1 à 31 jours' using errcode = 'PT400';
  end if;

  if not exists (
    select 1 from public.roles_utilisateur r
     where r.utilisateur_id = v_moi and r.salon_id = p_salon and r.role = 'gerant'
  ) then
    raise exception 'Historique réservé au gérant du salon' using errcode = 'PT403';
  end if;

  select s.fuseau_horaire into v_fuseau from public.salons s where s.id = p_salon;

  return query
    select r.id, r.coiffeur_id, co.nom, r.debut, r.fin, r.statut,
           p.nom, p.prix, cl.nom, e.montant, e.created_at
      from public.reservations r
      join public.prestations p on p.id = r.prestation_id
      join public.utilisateurs co on co.id = r.coiffeur_id
      join public.utilisateurs cl on cl.id = r.client_id
      left join public.encaissements e on e.reservation_id = r.id
     where r.salon_id = p_salon
       and r.statut in ('terminee', 'absent')
       and (p_coiffeur is null or r.coiffeur_id = p_coiffeur)
       and (r.debut at time zone v_fuseau)::date between p_du and p_au
     order by r.debut, co.nom;
end;
$$;

revoke execute on function public.historique(uuid, date, date, uuid) from public, anon;
grant execute on function public.historique(uuid, date, date, uuid) to authenticated;
