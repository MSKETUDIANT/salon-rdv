# Résultats des besoins non fonctionnels (BNF-1 à BNF-11)

Vérification de l'issue #12, selon la méthode prévue au cahier des charges
(`docs/cahier-des-charges.md`, § besoins non fonctionnels). Mesures du
2026-10-25, sur la branche `issue-12-verification-bnf`.

## Synthèse

| BNF | Priorité | Seuil (cahier des charges) | Résultat | Statut |
| --- | --- | --- | --- | --- |
| BNF-1 Fiabilité | Haute | zéro double réservation, même à la même seconde | 20 réservations simultanées : 1 réussite, 19 refus `PT409`, 1 ligne en base | **Passe** |
| BNF-2 Adéquation | Haute | 100 % des créneaux respectent la règle centrale | 38 tests sur des plannings types, toutes les branches de la règle couvertes | **Passe** |
| BNF-3 Sécurité | Haute | un client ne voit que ses réservations ; seul le gérant modifie horaires, absences, catalogue | tests d'accès par rôle sur toutes les tables ; Security Advisor : aucun défaut bloquant, 2 points tranchés par Sparta | **Passe** (protection des mots de passe : activation à confirmer) |
| BNF-4 Utilisabilité | Haute | un nouveau client réserve en moins de 2 min, sans aide | test avec 5 vrais utilisateurs à faire (`docs/bnf-4-fiche-test.md`) | **À faire** (Sparta) |
| BNF-5 Performance | Moyenne | liste des créneaux en moins de 3 s, téléphone d'entrée de gamme, 3G | médiane **1,75 s** en « Fast 3G » (3,33 s avant #46) | **Passe** depuis #46 (liste calculée par le serveur) |
| BNF-6 Maintenabilité | Moyenne | code en modules ; règles de réservation couvertes par des tests | découpe en modules relue ; règles de réservation couvertes (SQL, 100 % des lignes de `lib/` qui les appliquent) | **Passe** ; écart app pro comblé par #47, reste 1 écart mineur (site) |
| BNF-7 Portabilité | Basse | navigateur d'ordinateur et Android | Chrome sur ordinateur : automatique, réussi ; Android et navigateur de Sparta : à faire | **En partie**, reste manuel (Sparta) |
| BNF-8 Compatibilité | Basse | pas d'interopérabilité exigée en v1 | non exigé en v1 | **Sans objet** |
| BNF-9 Utilisabilité | Haute | 3 écrans au plus, hors authentification | 3 écrans (prestations, créneaux, confirmation) | **Passe** |
| BNF-10 Utilisabilité | Haute | 360 px sans défilement horizontal, zones tactiles ≥ 44 × 44 px, texte ≥ 16 px | 11 écrans et états : 0 écart | **Passe** |
| BNF-11 Utilisabilité | Haute | contrastes WCAG 2.2 AA | axe-core sur les 11 écrans et états : 0 écart ; jetons de la charte vérifiés | **Passe** |

## Rejouer les vérifications

Depuis `web/`, base locale démarrée (`supabase start`), Chrome et Flutter
installés :

- `npm run verifier:bnf` : tests SQL, tests unitaires avec couverture, tests
  de bout en bout, analyse et tests Flutter avec couverture. Bilan par étape,
  code de sortie 1 si l'une échoue. Durée : environ 2 minutes.
- `npm run verifier:bnf -- --perf` : en plus, la mesure BNF-5 sur la
  production (lecture seule).
- `npm run mesurer:bnf5` : la mesure BNF-5 seule.

Dernière exécution complète (2026-10-31, après #46, #39, #102 à #107, #110 et
#117) : 5 étapes sur 5 réussies, soit 466 tests SQL, 118 tests unitaires, 15
tests de bout en bout, analyse Flutter sans erreur et 264 tests Flutter.

Exécution précédente (2026-10-25, après `supabase db reset`) : 408 tests SQL,
106 tests unitaires, 11 tests de bout en bout, 71 tests Flutter.

**CI** : pas encore possible. GitHub Actions ne démarre pas, le compte est
verrouillé pour un problème de facturation (#19). La commande unique est prête
pour la CI le jour où #19 sera débloquée.

## BNF-1 — Fiabilité

- **Méthode** : `web/e2e/bnf-1-charge.spec.ts`. 20 comptes clients créés pour
  le test, puis 20 appels à `reserver()` lancés en même temps sur le même
  créneau (même chemin que le site), sur la base locale.
- **Résultat** : 1 réservation, 19 refus `PT409` (« Ce créneau n'est plus
  disponible »), une seule ligne non annulée en base. Les 20 réponses arrivent
  en 0,4 s environ.
- **Garantie** : la contrainte d'exclusion `reservations_sans_chevauchement`
  (PostgreSQL) empêche deux réservations non annulées qui se chevauchent pour
  un même coiffeur ; `reserver()` vérifie aussi le créneau et transforme le
  conflit en `PT409`.
- **Test réel en production (testeurs de Sparta, 2026-10-25)** : deux
  personnes réservent le même créneau en même temps.
  - **Premier essai** : toutes les deux voient une « liste vide », sans
    confirmation ni refus.
  - **Deuxième essai** : une seule réussit, l'autre est refusée.
  - **En base de production** (lecture seule, sans données personnelles) :
    aucune double réservation, une ligne par créneau. La garantie de la base
    a tenu ; le défaut était à l'écran.
  - **Reproduction en local** (#51, build de production sur la base locale,
    deux navigateurs) : 8 scénarios (même coiffeur, « Peu importe », passage
    par l'écran 2, retour par le bouton ou par le navigateur, réseau 3G et
    processeur ralenti, nouveau créneau après un refus ou une confirmation),
    plus des chargements simultanés de l'écran 2 en production. Chaque fois :
    un confirmé, un refusé (ou deux confirmés avec deux coiffeurs libres et
    « Peu importe »), jamais de liste vide. **La « liste vide » du premier
    essai n'est pas reproduite** ; il manque l'écran exact et une capture.
  - **Correction (#51)** : après un refus, retour automatique sur l'écran 2
    (prestation et coiffeur conservés), liste relue depuis la base sans la
    lecture anticipée, et « Ce créneau vient d'être pris. Choisissez-en un
    autre. » en tête ; le retour du navigateur ne ramène pas sur le créneau
    perdu. Test de bout en bout renforcé en conséquence
    (`reservation.spec.ts`).
  - **Nouveaux essais à deux en production, après déploiement**
    (2026-10-25, Sparta et deux testeurs, vérifiés en base en lecture seule) :
    - **même créneau, « Peu importe »** (samedi 31 octobre, 10:00, Coupe
      femme) : les deux validations arrivent à 2 ms d'écart ; les deux sont
      confirmées, l'une avec Amira, l'autre avec Youssef, tous deux libres.
      Comportement voulu (« Peu importe ») : aucun coiffeur n'a deux
      rendez-vous en même temps ;
    - **même créneau, même coiffeuse** (Amira, Coupe homme, mardi 27 octobre,
      18:30) : une réservation confirmée, l'autre client refusé et renvoyé
      sur l'écran 2 avec « Ce créneau vient d'être pris. Choisissez-en un
      autre. » en tête (capture de Sparta) ; une seule ligne en base.
    - **Contrôle de la base de production** : 0 chevauchement de
      réservations non annulées pour un même coiffeur.
    - **Étape intermédiaire relevée par Sparta** : avant la liste, le perdant
      voyait d'abord, sur l'écran 3, « Ce créneau vient d'être pris. Retour
      aux créneaux… » et un bouton « Choisir un autre créneau », le temps du
      renvoi (visible plus longtemps en production sur téléphone).
      **Corrigé** (#51, seconde PR) : rien ne s'affiche plus sur l'écran 3 ;
      le bouton reste « Réservation… » jusqu'à la liste, préchargée dès
      l'ouverture de l'écran 3. Le test de bout en bout enregistre tous les
      messages vus par le perdant : un seul, celui de la liste (le test
      échoue avec l'ancien comportement).
- **Autres tests** : `reservations_chevauchement.test.sql` (chevauchements,
  bout à bout autorisé, annulée libère), `reserver.test.sql`, et dans
  `reservation.spec.ts` deux clients qui valident en même temps dans deux
  navigateurs (un seul réussit, l'autre est renvoyé aux créneaux).

## BNF-2 — Adéquation fonctionnelle

- **Règle centrale** (`creneaux_disponibles()`) : un créneau proposé a la durée
  de la prestation, tombe dans les horaires du coiffeur, hors de ses absences,
  et ne chevauche aucune réservation non annulée.
- **Méthode** : chaque branche de la fonction est reliée à un test de
  `supabase/tests/creneaux_disponibles.test.sql` (plannings types : horaire
  coupé, absences, réservations, compétences, deux salons, deux pas de
  créneau). Le test 18 vérifie en plus, créneau par créneau, que chacun
  respecte toute la règle.

| Branche de la règle | Tests |
| --- | --- |
| Prestation active seulement | 17 ; prestation inconnue : 30 |
| Jamais dans le passé, fenêtre de 31 jours au plus, période à l'envers | 19, 20, 21 |
| Horaires du coiffeur, jour de la semaine, horaire coupé | 2, 9, 10 |
| Compétence du coiffeur | 13 |
| Coiffeur du salon de la prestation seulement | 14, 25, 26, 27 |
| Un coiffeur ou « Peu importe » | 15, 16 |
| Durée de la prestation, fin de plage | 9, 11, 12 |
| Pas du salon | 23, 24 |
| Absences (et bout à bout) | 4, 5 |
| Réservations non annulées (et bout à bout) ; annulée libère | 6, 7, 8 ; terminée et client absent bloquent : 31, 32 |
| Fuseau du salon ; changement d'heure | 3 ; 33, 34, 35 |
| Visiteur sans compte : créneaux sans données privées | 22, 36, 37 |

- **Ajouts de #12** : prestation inconnue (30), réservations terminée et
  « client absent » qui bloquent (31, 32), changement d'heure pour un salon à
  Paris (33 à 35), en vue du multi-salons. Résultat : 38 tests sur 38.
- **Branche sans effet** : le `distinct` (deux plages qui se recouvrent) ne
  sert plus depuis #9, qui interdit en base les plages qui se chevauchent
  (`horaires_sans_chevauchement`).
- **Même règle à la réservation** : `reserver()` relit
  `creneaux_disponibles()` avant d'insérer (`reserver.test.sql`).

## BNF-3 — Sécurité

### Tests d'accès par rôle

Chaque table a son fichier de tests RLS (`supabase/tests/rls_*.test.sql`),
avec un salon A et un salon B :

| Table | Visiteur | Client | Coiffeur | Gérant | Autre salon |
| --- | --- | --- | --- | --- | --- |
| `salons` | oui | oui | oui (ajouté en #12) | oui | oui |
| `utilisateurs` | oui | oui | oui | oui | oui |
| `roles_utilisateur` | oui (ajouté en #12) | oui | oui | oui | oui |
| `prestations` | oui | oui | oui | oui | oui |
| `competences` | oui | oui | oui | oui | oui |
| `horaires` | oui | oui | oui | oui | oui |
| `absences` | oui | oui | oui | oui | oui |
| `reservations` | oui | oui | oui | oui | oui |
| `encaissements` | oui | oui | oui | oui | oui |

Les fonctions ont leurs propres tests de droits : `reserver`,
`mes_reservations` et `annuler_reservation`, `planning`, `historique`,
`coiffeurs_du_salon`, `attribuer_role`, `creneaux_disponibles`. Exigences du
cahier :

- **un client ne voit que ses réservations** : `rls_reservations`,
  `mes_reservations.test.sql`, et `mes-reservations.spec.ts` (par l'API, un
  client ne lit ni n'annule la réservation d'un autre) ;
- **seul le gérant modifie horaires, absences et catalogue** : `rls_horaires`,
  `rls_absences`, `rls_prestations`, `rls_competences`,
  `configuration_salon.test.sql`.

### Security Advisor (`supabase db advisors`)

| Constat | Base locale | Base distante | Analyse |
| --- | --- | --- | --- |
| Fonctions `security definer` exécutables par `authenticated` (9) | — | avertissement | **Voulu** : ces fonctions sont le seul chemin d'accès (`reserver`, `planning`, `historique`…) et vérifient elles-mêmes le rôle de l'appelant ; tests de droits pour chacune. |
| `creneaux_disponibles` et `coiffeurs_du_salon` exécutables par `anon` | — | avertissement | **Voulu** : BF-C1, un visiteur voit les créneaux et les noms des coiffeurs sans compte ; aucune donnée privée renvoyée (tests 22, 36, 37 de BNF-2). |
| `public.rls_auto_enable()` exécutable par `anon` et `authenticated` | absente | avertissement | **Laissée et documentée** (décision de Sparta). Fonction installée par Supabase à la création du projet (option « activer la RLS automatiquement » sur les nouvelles tables), absente de nos migrations. Elle renvoie un `event_trigger` : PostgreSQL refuse de l'exécuter directement, l'exposition n'a donc pas d'effet. |
| Protection contre les mots de passe compromis désactivée (Auth) | — | avertissement | **À activer** (décision de Sparta, tableau de bord). Réglage d'Auth (vérification HaveIBeenPwned). Les clients se connectent par code e-mail, sans mot de passe ; seuls les comptes pros ont un mot de passe. |
| Plusieurs policies permissives pour un même rôle et une même action (5) | avertissement | avertissement | **Accepté** (performance) : une policy par rôle (client, coiffeur, gérant) reste plus lisible et plus facile à tester ; volumes d'un salon, sans effet mesurable. |

`npm audit` (site) : 0 vulnérabilité, dépendances de développement comprises.

### Décisions (Sparta, 2026-10-25)

1. **`public.rls_auto_enable()` : laissée telle quelle.** C'est la fonction de
   l'option « activer la RLS automatiquement » de Supabase : à chaque
   `create table` dans `public`, un déclencheur d'événement active la RLS sur
   la nouvelle table. Elle a été installée par Supabase à la création du
   projet distant, d'où son absence de nos migrations et de la base locale.
   Elle renvoie un `event_trigger` : PostgreSQL refuse de l'exécuter
   directement, donc son exposition à `anon` et `authenticated` par
   `/rest/v1/rpc` n'a pas d'effet. L'avertissement du Security Advisor est
   attendu et accepté. Ne pas la supprimer : la protection qu'elle apporte
   reste utile (toutes nos tables activent déjà la RLS dans leur migration).
2. **Protection contre les mots de passe compromis : activée par Sparta**
   dans le tableau de bord (Auth). À confirmer : nouvelle exécution de
   `supabase db advisors --linked` (l'avertissement doit disparaître). Si
   l'offre du projet ne permet pas de l'activer, le noter ici ; seuls les
   comptes pros ont un mot de passe (les clients se connectent par code).

## BNF-4 — Utilisabilité (à faire)

- **Méthode** : `docs/bnf-4-fiche-test.md`. 5 nouveaux clients (T1 à T5),
  chacun sur son téléphone, en navigation privée, sur le site de production,
  chronométrés sans aide ; le temps de Sparta sert de référence et ne compte
  pas parmi les 5.
- **Seuil** : moins de 2:00, sans aide, pour chacun des 5.
- **Indicatif** : l'automate fait le parcours en 2 à 3 s
  (`reservation.spec.ts`) ; cela ne remplace pas le test.
- **Résultats** : à reporter dans la fiche, puis ici (réussites sur 5, temps
  médian, temps le plus long, blocages répétés).

## BNF-5 — Performance

- **Méthode** : `web/scripts/bnf5-performance.mjs`, sur le site de
  production. Chrome, écran 360 × 800, tactile, processeur ralenti 4 fois
  (téléphone d'entrée de gamme), navigateur neuf et sans cache à chaque
  mesure. Mesure : du début de la navigation vers l'écran 2 jusqu'à
  l'affichage de la première heure proposée.
- **Préchauffage** : un appel non compté avant les 5 mesures, pour réveiller
  le site et la base (fonctions serverless « à froid ») ; sa durée est notée.
- **Profil** : « Fast 3G » des DevTools de Chrome (débit descendant
  1,44 Mb/s, montant 675 kb/s, latence 562,5 ms). C'est le seul profil qui
  compte pour le verdict.

| Date | Version | Préchauffage | Mesures (ms) | Médiane | Seuil 3 s |
| --- | --- | --- | --- | --- | --- |
| 2026-10-25 | liste rendue par React (#12) | 439 ms | 3 288, 3 288, 3 342, 3 377, 3 327 | **3,33 s** | dépassé de 0,33 s |
| 2026-10-31 | même version, nouvelle mesure | — | 3 368 à 3 551 | **3,43 s** | dépassé de 0,43 s |
| 2026-10-31 | **liste calculée par le serveur (#46)** | 1 514 ms | 1 720, 1 723, 1 753, 1 756, 2 225 | **1,75 s** | **tenu** (1,25 s de marge) |

**Verdict : BNF-5 passe** depuis #46 (PR #116, `806d05c`).

- **Ce que #46 a changé** (option A de Sparta) : la coquille de l'écran 2
  reste statique, mais la liste des créneaux est lue par le serveur à chaque
  visite et part dans le même HTML (`ensureStatic = "shell"`, `<Suspense>`).
  Les heures sont des liens vers l'écran 3, utilisables avant le JavaScript.
  JavaScript chargé avant la première heure : 17 Ko au lieu de 150 Ko. Le
  script de préchargement des créneaux a été retiré.
- **Préchauffage** : 1,5 s après le déploiement (fonction serveur « à
  froid ») ; non compté, comme avant.

Analyse d'avant #46, conservée :

- **Où passe le temps** (Fast 3G) : HTML complet à 0,67 s ; ensuite 142 Ko de
  JavaScript (compressé) à charger et à exécuter avec le processeur ralenti,
  avant que la liste, rendue par React, s'affiche. Les créneaux eux-mêmes
  sont demandés dès la réception du HTML (script de préchargement) et sur la
  même origine que le site (pas de connexion de plus) : ce n'est pas le
  goulot.
- **Écart expliqué** : avec 562,5 ms de latence par aller-retour, chaque
  ressource JavaScript coûte cher ; la liste dépend de l'exécution de React.
  BNF-5 n'est pas tenu en 3G.
- **Suite : issue #46** (décision de Sparta) : afficher la liste dès le HTML.
  Fait : voir le tableau ci-dessus.
- **Diagnostic seulement** : le script a aussi un profil
  `--profil=lighthouse` (150 ms de latence), utile pour isoler l'effet de la
  latence ; il ne change pas le verdict ci-dessus.
- **Facultatif** : mesure sur un vrai téléphone d'entrée de gamme en 3G
  (ouvrir l'écran 2 d'une prestation, chronométrer jusqu'à la première heure,
  3 fois).

## BNF-6 — Maintenabilité

### Découpe en modules

- **Base** (`supabase/`) : une migration par issue, une règle par fonction
  (`creneaux_disponibles`, `reserver`, `planning`, `historique`…), un fichier
  de tests par table ou par fonction.
- **Site** (`web/`) : `app/` (routes), `components/` par fonctionnalité
  (`reservation/`, `mes-reservations/`, `connexion/`) et `components/ui/`
  (composants de la charte), `lib/` (logique sans affichage : créneaux,
  réservation, formats, charte, accès à Supabase).
- **App pro** (`pro/`) : `lib/data/` (modèles et accès à Supabase derrière des
  interfaces), `lib/features/` par fonctionnalité (connexion, espaces,
  gérant, planning, historique), `lib/ui/` (charte, composants) ; les tests
  d'écran passent par des doublures des interfaces.
- **Règles de réservation** : dans la base (contrainte d'exclusion,
  `creneaux_disponibles`, `reserver`, transitions de statut), doublées côté
  site par `lib/reservation.ts` et `lib/creneaux.ts`.

### Couverture

| Partie | Couverture (lignes) | Règles de réservation |
| --- | --- | --- |
| Base | non mesurable en lignes pour le SQL | toutes les branches reliées à un test (BNF-2), 466 tests (2026-10-31) |
| Site, `lib/` | 82,3 % (2026-10-31) | `creneaux.ts`, `reservation.ts`, `mes-reservations.ts` : 100 % |
| Site, total (`npm run test:couverture`) | 77,7 % (branches 83,7 %) | — |
| App pro (`flutter test --coverage`) | 95,1 % (2026-10-31) ; `lib/data/` 96,8 % | règles dans la base |

**Écart mineur** :

- côté site, les pages serveur (`app/**/page.tsx`), `lib/supabase/` et les
  lectures faites par le serveur (`lib/salon.ts`, `lib/creneaux-serveur.ts`,
  #46 et #117) sont à 0 % en tests unitaires : les tests de bout en bout les
  couvrent (accueil, écran 2).

**Rattrapé le 2026-10-31** : les adaptateurs Supabase ajoutés après #47 (client
de passage, client arrivé, photo du salon, nom, mots de passe) n'avaient pas
de test propre ; `lib/data/` était retombé à 79,3 % et l'app pro à 92,5 %.
`test/data/adaptateurs_recents_test.dart` (18 tests, même fausse API) les
ramène à 96,8 % et 95,1 %.

**Comblé par #47** (2026-10-29) : côté app pro, `lib/data/` passe de 24 % à
98 % (adaptateurs Supabase testés avec une fausse API, `test/data/adaptateurs_test.dart` :
lecture des lignes à l'heure du salon, `numeric` en `double`, paramètres
envoyés, erreurs `PT400`, `PT403`, `PT409`, `23505`, `23514`, `42501`, `23P01`,
refus silencieux de la RLS) ; `ecran_equipe.dart` passe de 0 % à 100 %
(`test/features/equipe_test.dart`).

## BNF-7 — Portabilité

- **Automatique** : `web/e2e/bnf-7-ordinateur.spec.ts`, réservation complète
  dans Chrome sur ordinateur (1366 × 768, souris) : réussie, réservation en
  base, pas de défilement horizontal. Les autres tests de bout en bout
  tournent en Chrome avec l'émulation mobile (360 px, tactile).
- **Manuel, à faire (Sparta)** :
  - Android, site client : dans Chrome Android (l'émulateur suffit), une
    réservation complète puis son annulation depuis « Mes réservations » ;
  - Android, app pro : connexion, planning, fiche d'un rendez-vous,
    historique (déjà parcourus pendant les tests manuels de #10 et #11) ;
  - ordinateur, navigateur habituel de Sparta : une réservation complète.
- **Résultats** : à reporter ici (appareil, version d'Android, navigateur,
  réussi ou non, remarques).

## BNF-8 — Compatibilité

Non exigé en v1 : le cahier des charges ne demande aucune interopérabilité
(pas d'export d'agenda ni d'échange avec un autre logiciel).

## BNF-9 — 3 écrans au plus

`reservation.spec.ts` relève les écrans traversés : accueil, puis
`/reserver` (prestations), `/reserver/creneaux` et `/reserver/confirmation`,
soit 3 écrans hors accueil ; la connexion se fait sur l'écran 3, sans le
quitter. Réussi.

## BNF-10 — Mobile d'abord, 360 px

- **Seuils** : ceux du cahier des charges (44 × 44 px, 16 px), sans écart.
- **Méthode** : `web/e2e/bnf-10-11-ecrans.spec.ts`, à 360 px : accueil,
  prestations, créneaux, confirmation (non connecté, saisie du code,
  connecté), réservation confirmée, mes réservations (non connecté, connecté,
  demande d'annulation), page de la charte. Pour chaque écran : largeur du
  document comparée à celle de l'écran émulé, taille de chaque élément
  interactif visible, taille de chaque texte visible.
- **Contrôle des mesures** : le même test vérifie, sur une page aux défauts
  connus, que chaque défaut est bien détecté. Il a mis en évidence qu'en
  émulation mobile, `window.innerWidth` grandit quand le contenu déborde : la
  référence est donc la largeur de l'écran émulé (360 px).
- **Résultat** : 0 écart sur les 11 écrans et états.
- **App pro** : mêmes règles de charte (zones tactiles de 44 px, texte de
  16 px) ; les libellés de l'historique sont vérifiés à 360 px avec la vraie
  police (#11). Pas de mesure automatique écran par écran : prévu dans #41.

## BNF-11 — Contrastes WCAG 2.2 AA

- **Méthode** : audit axe-core (`@axe-core/playwright`, règle
  `color-contrast`) sur les 11 écrans et états de BNF-10, et
  `web/lib/charte.test.ts` sur les couples de couleurs de la charte (4,5:1
  pour le texte, 3:1 pour les composants).
- **Résultat** : 0 contraste insuffisant. Les autres règles WCAG 2.2 A et AA
  d'axe-core sont aussi relevées, sans faire échouer le test : aucune en
  défaut.
- **App pro** : contrastes des jetons vérifiés par `pro/test/ui/charte_test.dart`.
