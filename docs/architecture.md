# Architecture

Choix validé par Sparta le 2026-10-30 (#110, option A).

**En une phrase** : architecture deux niveaux sur un BaaS (Supabase), logique
métier en base (*thick database*), applications organisées par
fonctionnalité avec le patron Dépôt.

```
  Site client (Next.js)          App pro (Flutter)
  app/ → components/ → lib/      features/ → data/
            │                          │
            └──── clé anon + session ──┘
                         │
              Supabase : Auth, PostgREST
                         │
   PostgreSQL : contraintes, RLS, fonctions, déclencheurs  ← fait foi
```

Il n'y a pas de serveur d'API entre les applications et la base : elles
appellent Supabase directement, avec la clé publique `anon` et la session de
l'utilisateur.

## Pourquoi ce choix

- **Zéro double réservation**, la règle critique du projet : elle doit tenir
  quelle que soit l'application et même pour deux clics simultanés. Le seul
  endroit commun au site et à l'app pro est la base. La contrainte
  d'exclusion de `reservations` la garantit ; `reserver()` la double d'un
  contrôle et d'un verrou par coiffeur (#59).
- **La clé `anon` est publique** (dans le site et dans l'app) : seule la RLS
  protège réellement les données. Une vérification dans l'application ne
  protège rien.
- **Multi-salons** : le `salon_id` des tables propres à un salon et la RLS
  séparent les salons, sans changer les applications.
- **Projet court** (deux semaines) : pas de serveur de plus à écrire, déployer
  et surveiller.

Options écartées : une Clean Architecture complète dans chaque application
(règles écrites deux fois, en Dart et en TypeScript, qui finissent par
diverger) ; un serveur d'API intermédiaire (un composant de plus, sans
meilleure garantie que la contrainte en base).

## Règles

### 1. La base fait foi

Toute règle métier qui doit refuser une action est vérifiée par la base :
contrainte, RLS, fonction ou déclencheur. Une application peut la vérifier
aussi, mais seulement pour le confort de l'utilisateur (ne pas proposer une
action vouée à l'échec). Exemple : #104 ignore le toucher d'un créneau passé ;
la base le refuserait de toute façon.

Une règle s'écrit **une seule fois** en SQL. Si deux fonctions en ont besoin,
elle va dans une fonction commune du schéma `private` (exemple :
`private.reservation_annulable()`, #110). Si le site et l'app pro en ont
besoin, elle va dans une fonction publique que les deux appellent (exemple :
`horaires_du_salon()`, #129, horaires d'ouverture lus par l'accueil du site et
l'onglet Salon de l'app pro).

### 2. Deux chemins d'écriture, tous deux contrôlés par la base

| Chemin | Quand | Exemples |
| --- | --- | --- |
| **Fonction SQL** (`security definer`, appelée par `rpc`) | Action qui touche plusieurs tables, a besoin d'un verrou, ou que le client ne peut pas faire avec ses seuls droits | `reserver()`, `reserver_pour_client()`, `annuler_reservation()`, `attribuer_role()` |
| **Écriture directe dans une table** | Saisie simple d'un pro (gérant, coiffeur) sur une seule table | clôture (`reservations.statut`), encaissement, prestations, horaires, absences, compétences |

Une écriture directe n'est permise que si la table a une policy RLS pour ce
rôle, et que ses règles sont tenues par des contraintes ou des déclencheurs
(exemples : `verifier_transition_statut`, `verifier_encaissement`). Un client
du site n'écrit jamais directement : il passe par une fonction.

Chaque fonction ou policy a ses tests SQL dans `supabase/tests/`
(`supabase test db`).

### 3. Sens des dépendances

Dans chaque application, seule la couche d'accès aux données parle à
Supabase :

| | Écrans | Accès aux données | Commun |
| --- | --- | --- | --- |
| App pro | `lib/features/<fonction>/` | `lib/data/` | `lib/ui/` (charte, composants, formats) |
| Site | `app/` (pages), `components/<fonction>/` | `lib/` | `components/ui/`, `lib/format.ts`, `lib/charte.ts` |

- Un écran appelle la couche d'accès, jamais `Supabase` directement.
- `ui/` (`components/ui/`) ne connaît pas les données.
- Une fonctionnalité n'importe pas les fichiers privés d'une autre ; ce qui
  sert à plusieurs (exemple : `features/planning/elements_planning.dart`) est
  exporté par un seul fichier.

Le compte connecté du site (lecture de la session, déconnexion) passe aussi
par `lib/compte.ts` depuis #119 : aucun composant n'appelle Supabase.

### 4. Patron Dépôt dans l'app pro

Chaque domaine a, dans `lib/data/` :

- une interface (`abstract interface class DepotPlanning`, `DepotSalon`…) ;
- son implémentation Supabase (`PlanningSupabase`…) ;
- une doublure de test dans `test/doublures/` (`FauxPlanning`…).

Les écrans reçoivent l'interface : ils se testent sans réseau, avec la
doublure.

### 5. Rangement par fonctionnalité

Un dossier par fonction (planning, gérant, historique, accueil…), pas par
type technique. Repère de taille : un fichier qui dépasse **500 lignes** se
découpe par rôle (écran, sections, blocs d'affichage). C'est un repère, pas une
règle stricte.

### 6. État des écrans

L'état de chaque écran reste dans l'écran (`StatefulWidget` et `setState`,
composants React côté site), avec un chargement par `Chargement` dans l'app
pro. Un outil de gestion d'état (Riverpod, BLoC) ne se justifie que si un même
état doit être partagé entre plusieurs écrans ; ce n'est pas le cas
aujourd'hui.

## Évolutions de la base

- Toute modification passe par une migration de la CLI
  (`supabase migration new`), jamais par le dashboard.
- Une migration est validée par Sparta avant tout `db push`.
- Les types TypeScript sont régénérés après chaque migration
  (`web/lib/database.types.ts`).

## Points faibles

Corrigés par #110 (et #119 pour la règle 3 côté site) :

- La règle « annulable » était écrite deux fois (`mes_reservations()` et
  `annuler_reservation()`) : elle est maintenant dans
  `private.reservation_annulable()`.
- Trois fichiers de l'app pro dépassaient 800 lignes. Ils sont découpés sans
  changement de logique :
  - `elements_planning.dart` → `etat_rendez_vous`, `frise_jour`,
    `fiche_rendez_vous`, `navigation_dates` ;
  - `ecran_coiffeur.dart` → `section_horaires`, `section_absences`,
    `section_competences` ;
  - `ecran_aujourdhui.dart` → `blocs_aujourdhui`.

Restent connus :

- Certaines vérifications sont faites aussi dans les applications pour le
  confort (créneau passé, champs requis). Elles doivent rester alignées sur
  la base, qui fait foi.
- Autres points : `docs/dette-technique.md`.
