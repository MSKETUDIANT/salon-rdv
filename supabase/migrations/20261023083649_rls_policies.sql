-- Issue #3 : règles d'accès (RLS) par rôle et par salon (BNF-3).
-- La RLS est active sur les 9 tables depuis l'issue #1 ; on ajoute ici les
-- policies, les droits par colonne et le contrôle des transitions de statut.

-- ============================================================
-- Fonctions utilitaires (schéma private, non exposé par l'API)
-- ============================================================

create schema if not exists private;

grant usage on schema private to authenticated;

-- L'utilisateur connecté a-t-il ce rôle dans ce salon ?
-- security definer : lit roles_utilisateur sans repasser par ses policies.
create function private.a_le_role(p_salon uuid, p_role public.role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.roles_utilisateur
     where utilisateur_id = (select auth.uid())
       and salon_id = p_salon
       and role = p_role
  );
$$;

revoke execute on function private.a_le_role(uuid, public.role) from public;
grant execute on function private.a_le_role(uuid, public.role) to authenticated;

-- Cette personne est-elle coiffeur dans ce salon ?
-- security definer : le client ne lit pas les rôles des autres.
create function private.est_coiffeur_du_salon(p_id uuid, p_salon uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.roles_utilisateur
     where utilisateur_id = p_id
       and salon_id = p_salon
       and role = 'coiffeur'
  );
$$;

revoke execute on function private.est_coiffeur_du_salon(uuid, uuid) from public;
grant execute on function private.est_coiffeur_du_salon(uuid, uuid) to authenticated;

-- ============================================================
-- Droits de table et de colonne
-- ============================================================

-- anon ne fait que lire, sur toutes les tables.
revoke insert, update, delete, truncate, references, trigger
  on all tables in schema public from anon;

-- utilisateurs : aucun droit pour anon (les noms des coiffeurs se lisent via
-- coiffeurs_du_salon) ; authenticated ne modifie que nom et telephone
-- (l'e-mail suit auth.users).
revoke all on public.utilisateurs from anon, authenticated;
grant select on public.utilisateurs to authenticated;
grant update (nom, telephone) on public.utilisateurs to authenticated;

-- reservations : seule la colonne statut est modifiable par l'API.
revoke update on public.reservations from authenticated;
grant update (statut) on public.reservations to authenticated;

-- ============================================================
-- salons
-- ============================================================

create policy "salons : lecture publique"
  on public.salons for select
  to anon, authenticated
  using (true);

-- ============================================================
-- utilisateurs
-- ============================================================

create policy "utilisateurs : lecture de sa ligne"
  on public.utilisateurs for select
  to authenticated
  using (id = (select auth.uid()));

-- BF-K2 : le coiffeur voit les clients de ses réservations.
create policy "utilisateurs : coiffeur lit ses clients"
  on public.utilisateurs for select
  to authenticated
  using (
    exists (
      select 1
        from public.reservations r
       where r.client_id = utilisateurs.id
         and r.coiffeur_id = (select auth.uid())
    )
  );

create policy "utilisateurs : gérant lit les membres de son salon"
  on public.utilisateurs for select
  to authenticated
  using (
    exists (
      select 1
        from public.roles_utilisateur ru
       where ru.utilisateur_id = utilisateurs.id
         and private.a_le_role(ru.salon_id, 'gerant')
    )
  );

create policy "utilisateurs : modification de sa ligne"
  on public.utilisateurs for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- BF-C3 : noms des coiffeurs d'un salon, sans e-mail ni téléphone.
-- security definer : anon n'a aucun droit sur utilisateurs.
create function public.coiffeurs_du_salon(p_salon uuid)
returns table (id uuid, nom varchar)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.nom
    from public.utilisateurs u
    join public.roles_utilisateur ru on ru.utilisateur_id = u.id
   where ru.salon_id = p_salon
     and ru.role = 'coiffeur'
   order by u.nom;
$$;

revoke execute on function public.coiffeurs_du_salon(uuid) from public;
grant execute on function public.coiffeurs_du_salon(uuid) to anon, authenticated;

-- ============================================================
-- roles_utilisateur (écriture uniquement via attribuer_role)
-- ============================================================

create policy "roles : lecture de ses rôles"
  on public.roles_utilisateur for select
  to authenticated
  using (utilisateur_id = (select auth.uid()));

create policy "roles : gérant lit les rôles de son salon"
  on public.roles_utilisateur for select
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

-- ============================================================
-- prestations (pas de DELETE : on désactive avec active = false)
-- ============================================================

create policy "prestations : anon lit les actives"
  on public.prestations for select
  to anon
  using (active);

create policy "prestations : lecture des actives, gérant lit tout son salon"
  on public.prestations for select
  to authenticated
  using (active or private.a_le_role(salon_id, 'gerant'));

create policy "prestations : gérant crée"
  on public.prestations for insert
  to authenticated
  with check (private.a_le_role(salon_id, 'gerant'));

create policy "prestations : gérant modifie"
  on public.prestations for update
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'))
  with check (private.a_le_role(salon_id, 'gerant'));

-- ============================================================
-- competences
-- ============================================================

create policy "competences : lecture publique"
  on public.competences for select
  to anon, authenticated
  using (true);

-- La prestation est du salon du gérant, et la personne y est coiffeur.
create policy "competences : gérant ajoute"
  on public.competences for insert
  to authenticated
  with check (
    exists (
      select 1
        from public.prestations p
       where p.id = competences.prestation_id
         and private.a_le_role(p.salon_id, 'gerant')
         and private.est_coiffeur_du_salon(competences.coiffeur_id, p.salon_id)
    )
  );

create policy "competences : gérant retire"
  on public.competences for delete
  to authenticated
  using (
    exists (
      select 1
        from public.prestations p
       where p.id = competences.prestation_id
         and private.a_le_role(p.salon_id, 'gerant')
    )
  );

-- ============================================================
-- horaires
-- ============================================================

create policy "horaires : lecture publique"
  on public.horaires for select
  to anon, authenticated
  using (true);

create policy "horaires : gérant crée"
  on public.horaires for insert
  to authenticated
  with check (
    private.a_le_role(salon_id, 'gerant')
    and private.est_coiffeur_du_salon(coiffeur_id, salon_id)
  );

create policy "horaires : gérant modifie"
  on public.horaires for update
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'))
  with check (
    private.a_le_role(salon_id, 'gerant')
    and private.est_coiffeur_du_salon(coiffeur_id, salon_id)
  );

create policy "horaires : gérant supprime"
  on public.horaires for delete
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

-- ============================================================
-- absences (aucun accès anon ni client : plages occupées au sprint 2)
-- ============================================================

create policy "absences : coiffeur lit les siennes"
  on public.absences for select
  to authenticated
  using (coiffeur_id = (select auth.uid()));

create policy "absences : gérant lit son salon"
  on public.absences for select
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

create policy "absences : gérant crée"
  on public.absences for insert
  to authenticated
  with check (
    private.a_le_role(salon_id, 'gerant')
    and private.est_coiffeur_du_salon(coiffeur_id, salon_id)
  );

create policy "absences : gérant modifie"
  on public.absences for update
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'))
  with check (
    private.a_le_role(salon_id, 'gerant')
    and private.est_coiffeur_du_salon(coiffeur_id, salon_id)
  );

create policy "absences : gérant supprime"
  on public.absences for delete
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

-- ============================================================
-- reservations (pas de DELETE ; UPDATE limité à statut. Le WITH CHECK
-- borne le statut visé par rôle, le trigger borne les transitions)
-- ============================================================

create policy "reservations : client lit les siennes"
  on public.reservations for select
  to authenticated
  using (client_id = (select auth.uid()));

create policy "reservations : coiffeur lit les siennes"
  on public.reservations for select
  to authenticated
  using (
    coiffeur_id = (select auth.uid())
    and private.a_le_role(salon_id, 'coiffeur')
  );

create policy "reservations : gérant lit son salon"
  on public.reservations for select
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'));

-- Identité et cohérence du salon seulement. Horaires, absences, durée et
-- compétence du coiffeur : sprint 2 (voir docs/dette-technique.md).
create policy "reservations : client réserve pour lui"
  on public.reservations for insert
  to authenticated
  with check (
    client_id = (select auth.uid())
    and statut = 'confirmee'
    and private.a_le_role(salon_id, 'client')
    and exists (
      select 1 from public.prestations p
       where p.id = reservations.prestation_id
         and p.salon_id = reservations.salon_id
    )
    and private.est_coiffeur_du_salon(coiffeur_id, salon_id)
  );

create policy "reservations : client modifie les siennes"
  on public.reservations for update
  to authenticated
  using (client_id = (select auth.uid()))
  with check (
    client_id = (select auth.uid())
    and statut = 'annulee'
  );

create policy "reservations : coiffeur modifie les siennes"
  on public.reservations for update
  to authenticated
  using (
    coiffeur_id = (select auth.uid())
    and private.a_le_role(salon_id, 'coiffeur')
  )
  with check (
    coiffeur_id = (select auth.uid())
    and private.a_le_role(salon_id, 'coiffeur')
    and statut in ('terminee', 'absent')
  );

create policy "reservations : gérant modifie son salon"
  on public.reservations for update
  to authenticated
  using (private.a_le_role(salon_id, 'gerant'))
  with check (private.a_le_role(salon_id, 'gerant'));

-- Seules transitions permises : confirmee -> annulee, terminee ou absent.
-- S'applique à tous les rôles, y compris hors API.
create function public.verifier_transition_statut()
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

  return new;
end;
$$;

revoke execute on function public.verifier_transition_statut() from public, anon, authenticated;

create trigger reservations_transition_statut
  before update of statut on public.reservations
  for each row execute function public.verifier_transition_statut();

-- ============================================================
-- encaissements (pas de DELETE)
-- ============================================================

create policy "encaissements : gérant lit son salon"
  on public.encaissements for select
  to authenticated
  using (
    exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and private.a_le_role(r.salon_id, 'gerant')
    )
  );

create policy "encaissements : gérant enregistre"
  on public.encaissements for insert
  to authenticated
  with check (
    encaisse_par = (select auth.uid())
    and exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and private.a_le_role(r.salon_id, 'gerant')
    )
  );

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
    encaisse_par = (select auth.uid())
    and exists (
      select 1 from public.reservations r
       where r.id = encaissements.reservation_id
         and private.a_le_role(r.salon_id, 'gerant')
    )
  );
