-- Issue #5 : créneaux disponibles, visibles sans compte (BF-C1 à BF-C3).
-- Règle de gestion centrale (BNF-2) : un créneau proposé a la durée de la
-- prestation, tombe dans les horaires du coiffeur, hors de ses absences, et ne
-- chevauche aucune réservation.

-- ============================================================
-- Fuseau horaire du salon
-- ============================================================

-- Les horaires sont des heures locales (type time) : le fuseau du salon les
-- convertit en instants. Nom IANA ; Africa/Tunis par défaut (prix à 3
-- décimales : dinar tunisien).
alter table public.salons
  add column fuseau_horaire text not null default 'Africa/Tunis';

-- ============================================================
-- creneaux_disponibles
-- ============================================================

-- Créneaux libres d'une prestation, pour un coiffeur ou tous (p_coiffeur null :
-- « Peu importe »), du jour p_du au jour p_au inclus (dates locales du salon).
-- Créneaux tous les quarts d'heure à partir du début de chaque plage d'horaire.
-- Fenêtre bornée à 31 jours, jamais dans le passé.
-- security definer : anon ne lit ni absences ni réservations ; la fonction ne
-- renvoie que des créneaux, jamais de client ni de réservation.
create function public.creneaux_disponibles(
  p_prestation uuid,
  p_du date,
  p_au date,
  p_coiffeur uuid default null
)
returns table (coiffeur_id uuid, debut timestamptz, fin timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  with prestation as (
    select p.id, p.salon_id, make_interval(mins => p.duree_minutes) as duree,
           s.fuseau_horaire as fuseau
      from public.prestations p
      join public.salons s on s.id = p.salon_id
     where p.id = p_prestation
       and p.active
  ),
  jours as (
    select j::date as jour
      from prestation p,
           generate_series(
             greatest(p_du, (now() at time zone p.fuseau)::date),
             least(p_au, p_du + 30),
             interval '1 day'
           ) as j
  ),
  -- Plages de travail des coiffeurs du salon qui savent faire la prestation.
  plages as (
    select h.coiffeur_id,
           (j.jour + h.heure_debut) at time zone p.fuseau as debut,
           (j.jour + h.heure_fin) at time zone p.fuseau as fin
      from prestation p
      cross join jours j
      join public.horaires h
        on h.salon_id = p.salon_id
       and h.jour_semaine = extract(isodow from j.jour)
      join public.competences c
        on c.coiffeur_id = h.coiffeur_id
       and c.prestation_id = p.id
      join public.roles_utilisateur ru
        on ru.utilisateur_id = h.coiffeur_id
       and ru.salon_id = p.salon_id
       and ru.role = 'coiffeur'
     where p_coiffeur is null or h.coiffeur_id = p_coiffeur
  ),
  candidats as (
    select pl.coiffeur_id, t as debut, t + p.duree as fin
      from prestation p
      cross join plages pl
      cross join lateral generate_series(pl.debut, pl.fin - p.duree, interval '15 minutes') as t
  )
  -- distinct : deux plages d'horaire qui se recouvrent donnent les mêmes créneaux.
  select distinct c.coiffeur_id, c.debut, c.fin
    from candidats c
   where c.debut > now()
     and not exists (
       select 1
         from public.absences a
        where a.coiffeur_id = c.coiffeur_id
          and tstzrange(a.debut, a.fin, '[)') && tstzrange(c.debut, c.fin, '[)')
     )
     -- Même règle que la contrainte reservations_sans_chevauchement.
     and not exists (
       select 1
         from public.reservations r
        where r.coiffeur_id = c.coiffeur_id
          and r.statut <> 'annulee'
          and tstzrange(r.debut, r.fin, '[)') && tstzrange(c.debut, c.fin, '[)')
     )
   order by c.debut, c.coiffeur_id;
$$;

revoke execute on function public.creneaux_disponibles(uuid, date, date, uuid) from public;
grant execute on function public.creneaux_disponibles(uuid, date, date, uuid) to anon, authenticated;
