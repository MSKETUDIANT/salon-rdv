# salon_pro : app pro (coiffeurs et gérant)

Application Flutter de salon-rdv pour l'équipe du salon : Android et
navigateur (BNF-7). Les clients réservent sur le site (`web/`), pas ici.

## Configuration

Aucune clé dans le code : l'URL Supabase, la clé anon et le salon sont passés
au lancement par `--dart-define-from-file`. Les fichiers `config/*.json` sont
ignorés par Git, sauf le modèle `config/exemple.json`.

Base locale (`supabase start`, depuis la racine) :

1. copier `config/exemple.json` en `config/local.json` ;
2. y mettre `API_URL` et `ANON_KEY` de `supabase status -o env` ;
3. pour l'émulateur Android, faire une copie `config/android-local.json` avec
   `"SUPABASE_URL": "http://10.0.2.2:54321"` : depuis l'émulateur, la base
   locale ne répond pas sur `127.0.0.1`. Le HTTP en clair n'est autorisé qu'en
   debug (`android/app/src/debug/AndroidManifest.xml`).

## Commandes (dans `pro/`)

- Navigateur : `flutter run -d chrome --dart-define-from-file=config/local.json`
- Android : `flutter run -d emulator-5554 --dart-define-from-file=config/android-local.json`
- Analyse : `flutter analyze`
- Tests : `flutter test`

## Comptes de test (base locale, `supabase/seed.sql`)

Mot de passe : `motdepasse`.

| Compte | Rôles | Ce que montre l'app |
| --- | --- | --- |
| `amira@salon.test` | coiffeur | espace coiffeur |
| `gerant@salon.test` | gérant, client | espace gérant : prestations, équipe |
| `patron@salon.test` | gérant, coiffeur, client | choix de l'espace, puis bascule |
| `client@salon.test` | client | accès refusé |

En distant, le gérant est créé selon `docs/premier-gerant.md`.

## Structure

- `lib/ui/` : charte graphique du site traduite en `ThemeData`
  (`charte.dart`), composants de base (`composants.dart`).
- `lib/data/` : configuration, accès à Supabase (`session.dart`), espaces selon
  les rôles (`roles.dart`).
- `lib/features/` : écrans (connexion, aiguillage selon les rôles, espaces).
  `lib/features/gerant/` : configuration du salon (#9), c'est-à-dire
  prestations, équipe, et pour chaque coiffeur ses horaires, absences et
  compétences.
- `lib/data/salon.dart` : lectures et écritures de la configuration. Les
  droits sont vérifiés par la base (RLS) : l'app ne fait qu'afficher les
  refus.
- Polices Newsreader et Figtree embarquées (`assets/fonts/`, licence OFL).
