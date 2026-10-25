-- Issue #9 : configuration du salon par le gérant (BF-G1 à G3, BNF-3).
--
-- Les écritures sur horaires, absences, prestations et compétences sont déjà
-- réservées au gérant du salon par les policies de l'issue #3 (relues pour
-- #9, sans faille trouvée ; tests : supabase/tests/configuration_salon.test.sql).
-- Cette migration ferme trois cas que les policies laissaient passer, et
-- réserve la lecture des horaires et des absences aux comptes du salon.

-- ============================================================
-- prestations : le salon d'une prestation ne change pas
-- ============================================================

-- La policy « gérant modifie » laissait un gérant de deux salons déplacer une
-- prestation de l'un à l'autre : ses réservations et compétences seraient
-- restées rattachées à l'ancien salon. Seuls nom, prix, durée et activation
-- sont modifiables par l'API.
revoke update on public.prestations from authenticated;
grant update (nom, prix, duree_minutes, active) on public.prestations to authenticated;

-- Le nom est affiché aux clients : jamais vide ni fait d'espaces seulement.
alter table public.prestations
  add constraint prestations_nom_non_vide check (length(trim(nom)) > 0);

-- ============================================================
-- horaires : plages d'un même coiffeur sans chevauchement
-- ============================================================

-- Plusieurs plages par jour restent possibles (9h-13h et 14h-19h), mais deux
-- plages qui se recouvrent sont refusées : elles signalent une erreur de
-- saisie. Bout à bout autorisé ('[)'), comme pour les réservations. Tous
-- salons confondus : un coiffeur ne travaille pas à deux endroits à la fois.
-- La date fixe sert seulement à comparer des heures (lundi 3 janvier 2000).
alter table public.horaires
  add constraint horaires_sans_chevauchement exclude using gist (
    coiffeur_id with =,
    jour_semaine with =,
    tsrange(date '2000-01-03' + heure_debut, date '2000-01-03' + heure_fin, '[)') with &&
  );

-- ============================================================
-- horaires et absences : jamais lisibles sans compte
-- ============================================================

-- Les horaires de l'équipe étaient lisibles par tous (#3). Le site n'en a pas
-- besoin : creneaux_disponibles et reserver() les lisent eux-mêmes (security
-- definer). Lecture réservée aux comptes qui ont un rôle dans le salon
-- (gérant, coiffeur, client), par la policy « lecture de ses rôles » (#3).
drop policy "horaires : lecture publique" on public.horaires;

create policy "horaires : lecture par les comptes du salon"
  on public.horaires for select
  to authenticated
  using (
    exists (
      select 1 from public.roles_utilisateur ru
       where ru.utilisateur_id = (select auth.uid())
         and ru.salon_id = horaires.salon_id
    )
  );

-- Absences : aucune policy pour anon depuis #3 ; le droit de lecture est
-- retiré aussi, comme pour les horaires (double protection).
revoke select on public.horaires, public.absences from anon;
