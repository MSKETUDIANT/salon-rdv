-- Issue #151 (option A de Sparta) : le gérant donne la même plage à plusieurs
-- jours d'un coup (ex. du lundi au vendredi, 9 h – 18 h), et modifie une
-- plage existante (en la copiant au besoin sur d'autres jours).
-- definir_plages() enregistre tout ou rien : si un jour chevauche une plage
-- existante, aucune plage n'est créée et le message nomme le jour.
-- Security invoker : les policies de horaires (#3) s'appliquent telles
-- quelles (gérant du salon, coiffeur du salon).

create function public.definir_plages(
  p_salon     uuid,
  p_coiffeur  uuid,
  p_jours     integer[],
  p_debut     time,
  p_fin       time,
  p_remplace  uuid default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_jour  integer;
  v_noms  constant text[] := array['lundi', 'mardi', 'mercredi', 'jeudi',
                                   'vendredi', 'samedi', 'dimanche'];
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if p_jours is null or cardinality(p_jours) = 0 then
    raise exception 'Choisissez au moins un jour' using errcode = 'PT400';
  end if;

  if exists (select 1 from unnest(p_jours) j where j is null or j not between 1 and 7) then
    raise exception 'Jour invalide' using errcode = 'PT400';
  end if;

  if p_debut is null or p_fin is null or p_fin <= p_debut then
    raise exception 'La fin doit être après le début' using errcode = 'PT400';
  end if;

  -- Modification : l'ancienne plage est retirée d'abord (sinon elle se
  -- chevaucherait elle-même). Invisible ou d'un autre salon : introuvable.
  if p_remplace is not null then
    delete from public.horaires
     where id = p_remplace and salon_id = p_salon and coiffeur_id = p_coiffeur;
    if not found then
      raise exception 'Plage introuvable' using errcode = 'PT404';
    end if;
  end if;

  for v_jour in select distinct j from unnest(p_jours) j order by j loop
    begin
      insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
      values (p_salon, p_coiffeur, v_jour, p_debut, p_fin);
    exception when exclusion_violation then
      -- L'erreur annule toute la fonction : rien n'est enregistré.
      raise exception 'Chevauche une plage existante le %', v_noms[v_jour]
        using errcode = 'PT409';
    end;
  end loop;
end;
$$;

revoke execute on function public.definir_plages(uuid, uuid, integer[], time, time, uuid) from public, anon;
grant execute on function public.definir_plages(uuid, uuid, integer[], time, time, uuid) to authenticated;
