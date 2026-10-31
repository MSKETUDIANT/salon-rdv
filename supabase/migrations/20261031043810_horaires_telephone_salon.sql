-- Issue #129 (PR 2, option A de Sparta) : horaires d'ouverture et téléphone
-- du salon, affichés sur l'accueil du site.
--   1. horaires_du_salon() : la règle de #81 (option A), écrite une seule fois
--      ici et lue par le site et l'app pro : chaque jour, de la première
--      arrivée au dernier départ des coiffeurs du salon ; jour absent : fermé ;
--   2. salons.telephone, public comme le nom et l'adresse, changé seulement
--      par definir_telephone_salon(), par le gérant du salon (aucun droit
--      d'écriture sur salons).

-- ============================================================
-- horaires_du_salon
-- ============================================================

-- Une ligne par jour ouvert (1 = lundi ... 7 = dimanche), heures locales du
-- salon. Seuls comptent les coiffeurs qui ont encore le rôle dans ce salon.
-- security definer : anon ne lit pas roles_utilisateur ; la fonction ne
-- renvoie que des heures, jamais de coiffeur.
create function public.horaires_du_salon(p_salon uuid)
returns table (jour_semaine integer, ouverture time, fermeture time)
language sql
stable
security definer
set search_path = ''
as $$
  select h.jour_semaine, min(h.heure_debut), max(h.heure_fin)
    from public.horaires h
    join public.roles_utilisateur ru
      on ru.utilisateur_id = h.coiffeur_id
     and ru.salon_id = h.salon_id
     and ru.role = 'coiffeur'
   where h.salon_id = p_salon
   group by h.jour_semaine
   order by h.jour_semaine;
$$;

revoke execute on function public.horaires_du_salon(uuid) from public;
grant execute on function public.horaires_du_salon(uuid) to anon, authenticated;

-- ============================================================
-- salons.telephone
-- ============================================================

-- Numéro tel qu'affiché (« 71 234 567 », « +216 71 234 567 ») : chiffres,
-- espaces, points et tirets, « + » seulement au début, 8 à 15 chiffres.
-- null : pas de numéro (rien n'est affiché).
alter table public.salons
  add column telephone text,
  add constraint salons_telephone_format check (
    telephone ~ '^\+?[0-9][0-9 .-]*[0-9]$'
    and length(regexp_replace(telephone, '[^0-9]', '', 'g')) between 8 and 15
  );

comment on column public.salons.telephone is
  'Téléphone du salon tel qu''affiché (#129) ; null : pas de numéro.';

-- ============================================================
-- definir_telephone_salon
-- ============================================================

-- Le gérant de p_salon règle le numéro ; vide ou null : le retire. Espaces
-- en trop retirés.
-- Erreurs : PT401 non connecté ; PT403 pas gérant de ce salon ; PT400 numéro
-- invalide.
create function public.definir_telephone_salon(p_salon uuid, p_telephone text)
returns table (telephone text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_telephone text := nullif(regexp_replace(btrim(p_telephone), '\s+', ' ', 'g'), '');
begin
  if (select auth.uid()) is null then
    raise exception 'Connexion requise' using errcode = 'PT401';
  end if;

  if not private.a_le_role(p_salon, 'gerant') then
    raise exception 'Réglage réservé au gérant du salon' using errcode = 'PT403';
  end if;

  if v_telephone is not null and not (
    v_telephone ~ '^\+?[0-9][0-9 .-]*[0-9]$'
    and length(regexp_replace(v_telephone, '[^0-9]', '', 'g')) between 8 and 15
  ) then
    raise exception 'Numéro de téléphone invalide' using errcode = 'PT400';
  end if;

  update public.salons s
     set telephone = v_telephone
   where s.id = p_salon;

  return query select v_telephone;
end;
$$;

revoke execute on function public.definir_telephone_salon(uuid, text) from public, anon;
grant execute on function public.definir_telephone_salon(uuid, text) to authenticated;
