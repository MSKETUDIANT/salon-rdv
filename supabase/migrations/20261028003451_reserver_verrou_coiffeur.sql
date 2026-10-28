-- Issue #59 : réservations simultanées du même créneau sans interblocage.
-- Les insertions concurrentes vérifiées par reservations_sans_chevauchement
-- s'attendaient l'une l'autre et finissaient en « deadlock detected », en
-- délai dépassé, ou bloquaient le pool de connexions (20 appels simultanés :
-- aucun n'aboutissait). reserver() prend maintenant un verrou par coiffeur
-- avant d'insérer : les réservations d'un même coiffeur passent l'une après
-- l'autre, et la contrainte reste le dernier rempart.

create or replace function public.reserver(
  p_prestation uuid,
  p_debut timestamptz,
  p_coiffeur uuid default null
)
returns table (id uuid, coiffeur_id uuid, debut timestamptz, fin timestamptz)
language plpgsql
security definer
set search_path = ''
-- Attente du verrou bornée. (Un statement_timeout posé ici serait sans effet :
-- celui de la requête en cours est déjà armé à l'appel de la fonction.)
set lock_timeout = '3s'
as $$
declare
  v_client     uuid := (select auth.uid());
  v_salon      uuid;
  v_fuseau     text;
  v_duree      interval;
  v_jour       date;
  v_candidats  uuid[];
  v_candidat   uuid;
  v_id         uuid;
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

  -- Coiffeurs libres à cette heure, le moins chargé du jour d'abord.
  select array_agg(c.coiffeur_id order by (
           select count(*) from public.reservations r
            where r.coiffeur_id = c.coiffeur_id
              and r.statut <> 'annulee'
              and (r.debut at time zone v_fuseau)::date = v_jour
         ), c.coiffeur_id)
    into v_candidats
    from public.creneaux_disponibles(p_prestation, v_jour, v_jour, p_coiffeur) as c
   where c.debut = p_debut;

  -- Un verrou par coiffeur candidat, jusqu'à la fin de la transaction, pris
  -- dans l'ordre des identifiants : deux réservations qui visent les mêmes
  -- coiffeurs (« Peu importe ») ne peuvent pas s'attendre en croix.
  perform pg_advisory_xact_lock(hashtextextended('reservations:' || c::text, 0))
     from unnest(v_candidats) as c
    order by c;

  -- Après le verrou, chaque insertion voit les réservations validées entre-temps :
  -- un conflit lève exclusion_violation tout de suite, sans attente.
  foreach v_candidat in array coalesce(v_candidats, '{}') loop
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
