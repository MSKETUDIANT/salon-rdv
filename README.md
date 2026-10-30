# salon-rdv

Gestionnaire de rendez-vous pour un salon de coiffure.

- **Clients** : un site web pour réserver sans installer d'application.
- **Équipe** (coiffeurs, gérant) : une app Flutter, sur Android et dans le
  navigateur.

Un seul salon en v1 ; la base est prête pour plusieurs salons.

## En ligne

| Quoi | Adresse |
| --- | --- |
| Site client (production) | https://salon-rdv-one.vercel.app |
| App pro (Android, APK) | https://github.com/MSKETUDIANT/salon-rdv/releases/tag/app-pro-v0.2.0 |
| Dépôt | https://github.com/MSKETUDIANT/salon-rdv |

Les données en ligne sont des **données de démonstration** (deux coiffeurs
fictifs, quatre prestations) : `docs/donnees-demo.md`.

## Architecture

```
  Clients (navigateur)               Équipe (Android, navigateur)
          │                                    │
          ▼                                    ▼
  Site Next.js (web/)                  App Flutter (pro/)
  hébergé sur Vercel                   APK ou build web
          │                                    │
          └──────────────┬─────────────────────┘
                         ▼
          Supabase : PostgreSQL, Auth, RLS (supabase/)
```

- **Base et règles métier** : PostgreSQL (Supabase). Toutes les règles sont
  dans la base : sécurité par RLS, fonctions SQL (`creneaux_disponibles`,
  `reserver`, `planning`, `historique`…), et **zéro double réservation**
  garanti par une contrainte d'exclusion. Les apps ne font qu'afficher.
- **Site client** (`web/`) : Next.js, TypeScript, Tailwind. Connexion par code
  à 6 chiffres reçu par e-mail, au moment de réserver.
- **App pro** (`pro/`) : Flutter. Connexion par e-mail et mot de passe ;
  espace coiffeur (planning, clôture des rendez-vous) et espace gérant
  (configuration du salon, planning de l'équipe, encaissements, historique).

| Dossier | Contenu |
| --- | --- |
| `supabase/migrations/` | schéma, RLS et fonctions, une migration par fonctionnalité |
| `supabase/tests/` | tests SQL (pgTAP) |
| `supabase/seed.sql` | données de développement local |
| `supabase/demo/` | données de démonstration pour la base distante |
| `web/` | site client (Next.js) |
| `pro/` | app pro (Flutter), détails dans `pro/README.md` |
| `docs/` | cahier des charges, charte graphique, procédures, résultats |

## Prérequis

| Outil | Version utilisée | Pour |
| --- | --- | --- |
| Git | — | cloner le dépôt |
| Docker Desktop | 29 | base locale |
| Supabase CLI | 2.105 | base locale, migrations, déploiement de la base |
| Node.js et npm | 24 et 11 | site client |
| Flutter | 3.41 (Dart 3.11) | app pro |
| Google Chrome | récent | tests de bout en bout, app pro dans le navigateur |
| Android SDK (facultatif) | 36 | app pro sur Android (émulateur ou téléphone) |

## Installer et lancer en local

Toutes les commandes partent de la racine du dépôt, sauf mention contraire.

### 1. Base locale

```bash
git clone https://github.com/MSKETUDIANT/salon-rdv.git
cd salon-rdv
supabase start        # Docker Desktop doit tourner
supabase db reset     # applique les migrations et les données de supabase/seed.sql
supabase status -o env
```

Garder la sortie de `supabase status -o env` : `API_URL` et `ANON_KEY`
servent aux deux apps. Studio (interface de la base) :
http://127.0.0.1:54323 ; e-mails envoyés en local (codes de connexion) :
Mailpit, http://127.0.0.1:54324.

### 2. Site client

```bash
cd web
cp .env.example .env.local
```

Dans `web/.env.local` :

```
NEXT_PUBLIC_SUPABASE_URL=<API_URL>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<ANON_KEY>
NEXT_PUBLIC_SALON_ID=11111111-1111-1111-1111-111111111111
```

```bash
npm ci
npm run dev           # http://localhost:3000
```

Pour réserver, saisir n'importe quelle adresse : le code arrive dans Mailpit.

### 3. App pro

```bash
cd pro
cp config/exemple.json config/local.json   # puis y mettre API_URL et ANON_KEY
flutter pub get
flutter run -d chrome --dart-define-from-file=config/local.json
```

Pour l'émulateur Android, une copie `config/android-local.json` avec
`"SUPABASE_URL": "http://10.0.2.2:54321"`, puis
`flutter run -d emulator-5554 --dart-define-from-file=config/android-local.json`
(détails : `pro/README.md`).

### Comptes de test (base locale)

Mot de passe : `motdepasse`.

| Compte | Rôle | Où |
| --- | --- | --- |
| `gerant@salon.test` | gérant | app pro, espace gérant |
| `amira@salon.test`, `youssef@salon.test` | coiffeurs | app pro, espace coiffeur |
| `patron@salon.test` | gérant et coiffeur | app pro, choix de l'espace |
| `client@salon.test` | client | site (connexion par code, dans Mailpit) |

Le seed local contient des rendez-vous d'hier (à clôturer, à encaisser), de
mardi prochain et du mercredi suivant, une absence et un rendez-vous annulé.

## Base de données : migrations

Toute modification du schéma passe par une migration de la CLI, jamais par du
SQL appliqué à la main.

```bash
supabase migration new <nom>     # crée supabase/migrations/<horodatage>_<nom>.sql
supabase db reset                # rejoue toutes les migrations et le seed en local
supabase test db                 # tests SQL
supabase gen types typescript --local > web/lib/database.types.ts   # après chaque migration
supabase migration list          # migrations en local et en distant
supabase db push                 # envoie les migrations à la base distante
```

`supabase db push` et `migration list` en distant demandent un projet lié
(`supabase link --project-ref <ref>`, une fois). Ordre de mise en ligne :
merge de la PR sur `main`, puis `db push` depuis `main`, puis
`supabase migration list` (mêmes versions dans les colonnes Local et Remote).

## Tests

| Commande | Dossier | Contenu |
| --- | --- | --- |
| `supabase test db` | racine | tests SQL : règles métier, RLS, fonctions |
| `npm test` | `web/` | tests unitaires (Vitest) |
| `npm run test:e2e` | `web/` | bout en bout (Playwright, Chrome) sur la base locale |
| `npm run lint` et `npm run build` | `web/` | lint, charte graphique, build |
| `flutter analyze` et `flutter test` | `pro/` | analyse et tests de l'app pro |
| `npm run verifier:bnf` | `web/` | tout ce qui précède, avec couverture, en une commande |

Résultats des besoins non fonctionnels : `docs/resultats-bnf.md`.

## Déployer

### Base distante (Supabase)

1. Créer un projet Supabase, puis `supabase link --project-ref <ref>`.
2. `supabase db push`, puis `supabase migration list`.
3. Créer le salon et le premier gérant : `docs/premier-gerant.md`.
4. Facultatif, données de démonstration : `docs/donnees-demo.md`.
5. Connexion des clients par code : `docs/connexion-code-email.md` (serveur
   d'envoi SMTP et modèles d'e-mail).

### Site client (Vercel)

1. Importer le dépôt GitHub dans Vercel, avec **`web`** comme dossier racine
   (Root Directory) ; Next.js est détecté.
2. Variables d'environnement (Production et Preview) :
   `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (clé anon du
   projet distant, jamais la clé service) et `NEXT_PUBLIC_SALON_ID`.
3. Chaque merge sur `main` déploie la production ; chaque PR a sa preview.
   Le build lit la base distante : une PR dont le site dépend d'une migration
   pas encore poussée a une preview en échec jusqu'au `db push`.

### Déployer l'app pro

Configuration de production : copier `pro/config/exemple.json` en
`pro/config/production.json` (ignoré par Git) avec l'URL et la clé anon du
projet distant et l'id du salon. Puis, dans `pro/` :

```bash
flutter build web --release --dart-define-from-file=config/production.json   # build/web : site statique
flutter build apk --release --dart-define-from-file=config/production.json   # build/app/outputs/flutter-apk/app-release.apk
```

- **Build web** : dossier statique `build/web`, à publier sur n'importe quel
  hébergement de fichiers statiques.
- **APK** : installable directement sur Android (autoriser les sources
  inconnues). Il est signé avec la clé de debug de Flutter : suffisant pour
  une démonstration, pas pour le Play Store (il faudrait une clé de
  signature dédiée).

Publication retenue : **l'APK, joint à une release GitHub** (projet de
formation, pas de build web en ligne). Pour une nouvelle version : augmenter
`version` dans `pro/pubspec.yaml`, construire l'APK depuis `main`, puis
`gh release create app-pro-v<version> <apk> --target <commit>` avec
l'empreinte SHA-256 de l'APK dans les notes.

## Documentation

| Document | Contenu |
| --- | --- |
| `docs/cahier-des-charges.md` | besoins fonctionnels (BF) et non fonctionnels (BNF) |
| `docs/architecture.md` | architecture : couches, règles, points faibles |
| `docs/demonstration-bf.md` | les 15 besoins fonctionnels, démontrés un par un |
| `docs/resultats-bnf.md` | mesures et résultats des besoins non fonctionnels |
| `docs/charte-graphique.md` | couleurs, typographie, composants |
| `docs/premier-gerant.md` | créer le salon et le premier gérant en distant |
| `docs/donnees-demo.md` | données de démonstration en distant |
| `docs/connexion-code-email.md` | connexion des clients par code e-mail |
| `docs/dette-technique.md` | points connus laissés pour plus tard |
| `pro/README.md` | app pro : configuration, commandes, structure |
