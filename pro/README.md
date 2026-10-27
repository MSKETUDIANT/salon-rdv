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

## Essayer les gestes (base locale)

L'onglet « Aujourd'hui » ne propose les gestes (à droite « Terminé », à
gauche « Client absent ») que sur un rendez-vous commencé. Pour en avoir à
toute heure, `supabase/demo/gestes-locaux.sql` crée pour Amira six
rendez-vous calés sur l'heure actuelle : un terminé, un absent, un à
clôturer, un en cours, deux à venir. **Base locale uniquement** ; relançable
(il remplace ses propres rendez-vous et annule les rendez-vous confirmés
d'Amira qui les chevauchent).

Depuis la racine du dépôt, base locale démarrée :

- PowerShell :
  `Get-Content -Raw supabase\demo\gestes-locaux.sql | docker exec -i supabase_db_salon-rdv psql -U postgres -v ON_ERROR_STOP=1`
- Bash :
  `docker exec -i supabase_db_salon-rdv psql -U postgres -v ON_ERROR_STOP=1 < supabase/demo/gestes-locaux.sql`

Puis se connecter avec `amira@salon.test` (ou `gerant@salon.test` pour la vue
du salon). L'indice du geste ne s'affiche qu'une fois par appareil : pour le
revoir, effacer les données de l'app.

## Icône de l'app

« S » blanc sur fond accent, en Newsreader (#55, `docs/charte-graphique.md`
§4). Sources dans `assets/icone/` : `icone.png` (icône pleine, 1024 px) et
`icone-premier-plan.png` (premier plan transparent de l'icône adaptative
Android, « S » agrandi pour compenser la marge de 16 % ajoutée par l'outil).
Après un changement de ces images, régénérer les icônes Android et web :

```
dart run flutter_launcher_icons
```

La configuration est dans `pubspec.yaml` (`flutter_launcher_icons:`).

## Structure

- `lib/ui/` : charte graphique du site traduite en `ThemeData`
  (`charte.dart`), composants de base (`composants.dart`).
- `lib/data/` : configuration, accès à Supabase (`session.dart`), espaces selon
  les rôles (`roles.dart`).
- `lib/features/` : écrans (connexion, aiguillage selon les rôles, espaces).
  `lib/features/gerant/` : configuration du salon (#9), c'est-à-dire
  prestations, équipe, et pour chaque coiffeur ses horaires, absences et
  compétences. `lib/features/planning/` : plannings (#10), « Mon planning »
  du coiffeur (jour, semaine, détail) et planning de l'équipe pour le
  gérant ; depuis la fiche d'un rendez-vous, clôture (terminé, client
  absent) et encaissement par le gérant (#11). `lib/features/historique/` :
  historique du gérant (#11), filtré par période et par coiffeur.
- `lib/data/planning.dart` : rendez-vous par la fonction SQL `planning()` (le
  coiffeur ne reçoit que les siens, nom et téléphone du client seulement) ;
  clôture, encaissement et historique (`historique()`), règles vérifiées par
  la base.
- `lib/data/salon.dart` : lectures et écritures de la configuration. Les
  droits sont vérifiés par la base (RLS) : l'app ne fait qu'afficher les
  refus.
- Polices Newsreader et Figtree embarquées (`assets/fonts/`, licence OFL).
