-- Données de démonstration présentes (voir donnees-demo.sql, docs/donnees-demo.md).
-- Attendu : Amira et Youssef, rôles client et coiffeur, 4 et 2 compétences,
-- 10 et 6 plages d'horaire ; 4 prestations de démo actives.
select u.nom,
       u.email,
       (select string_agg(r.role::text, ', ' order by r.role)
          from public.roles_utilisateur r where r.utilisateur_id = u.id) as roles,
       (select count(*) from public.competences k where k.coiffeur_id = u.id) as competences,
       (select count(*) from public.horaires h where h.coiffeur_id = u.id) as horaires,
       (select count(*) from public.prestations p
         where p.id::text like 'de300000-0000-4000-8000-%' and p.active) as prestations_demo
  from public.utilisateurs u
 where u.id::text like 'de300000-0000-4000-8000-%'
 order by u.nom;
