-- Issue #9 : configuration du salon par le gérant (BF-G1 à G3, BNF-3).
--
-- Les écritures sur horaires, absences, prestations et compétences sont déjà
-- réservées au gérant du salon par les policies de l'issue #3 (relues pour
-- #9, sans faille trouvée ; tests : supabase/tests/configuration_salon.test.sql).
-- Cette migration ne touche à aucune policy : elle ferme trois cas que les
-- policies laissaient passer.

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
