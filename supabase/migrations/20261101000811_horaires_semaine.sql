-- Issue #151, option B de Sparta : un seul écran « Horaires de la semaine »
-- (un interrupteur par jour, heures modifiables, copie vers d'autres jours,
-- pauses), enregistré en une fois. Remplace definir_plages() de la migration
-- précédente (même issue, jamais mise en ligne : l'écran plage par plage a
-- été jugé peu pratique).
--
-- definir_semaine() remplace toutes les plages du coiffeur dans le salon par
-- celles reçues, tout ou rien : une plage invalide ou deux plages qui se
-- chevauchent un même jour, et rien ne change (le jour est nommé).
-- Security invoker : les policies de horaires (#3) s'appliquent ; le rôle de
-- gérant est aussi vérifié d'entrée (sinon la suppression ne ferait rien en
-- silence).

drop function public.definir_plages(uuid, uuid, integer[], time, time, uuid);

create function public.definir_semaine(
  p_salon    uuid,
  p_coiffeur uuid,
  p_plages   jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_plage jsonb;
  v_jour  integer;
  v_debut time;
  v_fin   time;
  v_noms  constant text[] := array['lundi', 'mardi', 'mercredi', 'jeudi',
                                   'vendredi', 'samedi', 'dimanche'];
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if not private.a_le_role(p_salon, 'gerant') then
    raise exception 'Action réservée au gérant du salon' using errcode = '42501';
  end if;

  if p_plages is null or jsonb_typeof(p_plages) <> 'array' then
    raise exception 'Horaires invalides' using errcode = 'PT400';
  end if;

  delete from public.horaires
   where salon_id = p_salon and coiffeur_id = p_coiffeur;

  for v_plage in select * from jsonb_array_elements(p_plages) loop
    begin
      v_jour  := (v_plage ->> 'jour')::integer;
      v_debut := (v_plage ->> 'debut')::time;
      v_fin   := (v_plage ->> 'fin')::time;
    exception when others then
      raise exception 'Horaires invalides' using errcode = 'PT400';
    end;

    if v_jour is null or v_jour not between 1 and 7 then
      raise exception 'Horaires invalides' using errcode = 'PT400';
    end if;

    if v_debut is null or v_fin is null or v_fin <= v_debut then
      raise exception 'La fin doit être après le début le %', v_noms[v_jour]
        using errcode = 'PT400';
    end if;

    begin
      insert into public.horaires (salon_id, coiffeur_id, jour_semaine, heure_debut, heure_fin)
      values (p_salon, p_coiffeur, v_jour, v_debut, v_fin);
    exception when exclusion_violation then
      -- L'erreur annule toute la fonction : les anciennes plages restent.
      raise exception 'Deux plages se chevauchent le %', v_noms[v_jour]
        using errcode = 'PT409';
    end;
  end loop;
end;
$$;

revoke execute on function public.definir_semaine(uuid, uuid, jsonb) from public, anon;
grant execute on function public.definir_semaine(uuid, uuid, jsonb) to authenticated;
