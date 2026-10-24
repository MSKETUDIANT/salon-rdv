# CLAUDE.md — salon-rdv

## 1. Projet
salon-rdv : gestionnaire de rendez-vous pour un salon de coiffure.
Projet d'entraînement, livré en deux semaines (5 sprints).
- Clients : site Next.js (réservation sans application à installer).
- Pros (coiffeur, gérant) : app Flutter.
- Un seul salon en v1, mais la base est prête pour le multi-salons.
Référence : docs/cahier-des-charges.md (besoins BF-*, BNF-*).
Backlog : GitHub Projects n°3 (MSKETUDIANT), une issue = une tâche.
Règle métier critique : zéro double réservation, garantie par la base
(contrainte d'exclusion PostgreSQL), doublée d'une vérification backend.

## 2. Stack
- Base et backend : Supabase (PostgreSQL, Auth, RLS) + Supabase CLI.
- Site client : Next.js + TypeScript + Tailwind, déployé sur Vercel.
- App pro : Flutter / Dart.
- Tests : Vitest (unitaires), Playwright (bout en bout), tests SQL pour la base.
- Base locale : Docker Desktop, via `supabase start`.

## 3. Commandes
- Base locale : `supabase start` / `supabase stop`
- Nouvelle migration : `supabase migration new <nom>`
- Rejouer la base locale : `supabase db reset`
- État des migrations : `supabase migration list`
- Envoyer au distant : `supabase db push` (uniquement avec mon accord)
- Types TypeScript de la base (depuis la racine) :
  `supabase gen types typescript --local > web/lib/database.types.ts`
- Site client (dans `web/`, variables dans `web/.env.local`, modèle `.env.example`) :
  `npm run dev` / `npm run build` / `npm run lint` / `npm test`
- CI (GitHub Actions, `.github/workflows/ci.yml`) : jobs `base` et `web` sur
  chaque PR ; résultat dans l'onglet *Checks* de la PR ou via `gh pr checks <n>`.
(Compléter cette section quand l'app existera.)

## 4. Règles de travail
- Montre ton plan avant d'exécuter. Attends ma validation.
- Quand je demande à voir quelque chose avant une action, montre-le,
  puis arrête-toi et attends mon accord.
- Ne dis jamais « c'est fait » sans preuve : sortie de commande, test, capture.
- Ne supprime rien (fichier, branche, projet, donnée) sans mon accord explicite.
- Une issue à la fois. Ne touche pas à ce qui est hors de l'issue en cours.
- Si une consigne te paraît fausse ou contradictoire, dis-le avant d'agir.
- Si tu ne sais pas, dis-le. Ne devine pas.
- Ordre de mise en ligne : merge de la PR sur main, puis db push depuis main.

## 5. Conventions
- Toute modification de la base passe par une migration de la CLI.
  Jamais de SQL appliqué à la main dans le dashboard.
- Une branche par issue : `issue-<n>-<sujet-court>`.
- Commits en français, format : `type: description`
  (feat, fix, docs, test, refactor, chore).
- Commit lié à l'issue : `(#<n>)` dans le message.
- Pas de secret dans le dépôt : clés dans `.env.local`, ignoré par Git.
- Les noms des coiffeurs se lisent via coiffeurs_du_salon().
- Régénérer les types après chaque migration.

## 6. Définition de « fini »
Une issue est finie quand :
1. le code répond aux critères de l'issue ;
2. les tests sont écrits et passent ;
3. les migrations sont listées en local (`supabase migration list`) ;
4. l'issue est passée en « À vérifier » ;
5. Claude Code merge lui-même les PR (« Refs #<n> »), à condition que lint,
   tests et build passent. Sparta ne valide que deux choses : le rendu visuel
   (sur la preview) et les migrations de base, avant tout db push. Le merge ne
   ferme pas l'issue ;
6. après le merge, db push depuis main, puis `supabase migration list` en local
   et en distant. L'issue ne passe en « Done » qu'après ce point 6 : je la ferme
   avec la sortie de `migration list` en commentaire, et l'automatisation la
   passe en « Done ». Si l'issue n'a pas de migration, ferme-la directement
   après le merge. Le commentaire de fermeture indique ce que Sparta a validé.