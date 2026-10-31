# Charte graphique — site client

Statut : décisions validées par Sparta le 23/10/2026 (issue #20, étape 1).
Aucune couleur ni police hors de ce document. Implémentation : étape 2 de #20.

## 1. Direction

Simple, léger, tranquille. Une ambiance sobre et contrastée, inspirée de
Planity ; le catalogue de prestations en cartes, inspiré de Fresha. Identité
propre : on s'inspire, on ne copie pas.

À éviter : dégradés, glassmorphism, illustrations génériques, textes marketing
creux. Mode clair uniquement en v1 (le mode sombre est l'issue #21).

## 2. Palette

Toutes les couleurs sont des jetons définis à un seul endroit : le thème
Tailwind 4 (`@theme`) dans `web/app/globals.css`. Changer l'accent = changer une
ligne. Aucune couleur écrite en dur ailleurs.

**Un seul accent** : pas de couleur supplémentaire. Les confirmations et succès
utilisent l'accent.

| Jeton | Valeur | Usage | Contraste sur `fond` | sur `surface` | Seuil WCAG 2.2 AA |
| --- | --- | --- | --- | --- | --- |
| `fond` | #FAFAF7 | fond de page | — | — | — |
| `surface` | #FFFFFF | cartes, champs | — | — | — |
| `texte` | #1A1A1A | texte principal | 16,6:1 | 17,4:1 | 4,5:1 |
| `texte-secondaire` | #5C5C5C | durées, aides, mentions | 6,4:1 | 6,7:1 | 4,5:1 |
| `bordure` | #8A8A8A | bordure des champs et du bouton secondaire | 3,3:1 | 3,5:1 | 3:1 (composant) |
| `separateur` | #E5E3DE | traits décoratifs ; fond des créneaux indisponibles | 1,2:1 | 1,3:1 | aucun (décoratif) |
| `accent` | #1F5C4A | bouton principal, liens, focus, succès | 7,5:1 | 7,8:1 | 4,5:1 |
| `accent-survol` | #174536 | survol du bouton principal | — | — | — |
| `erreur` | #B42318 | messages et bordures d'erreur | 6,3:1 | 6,6:1 | 4,5:1 |

Autres couples utilisés :

| Texte | Fond | Contraste | Usage |
| --- | --- | --- | --- |
| blanc #FFFFFF | `accent` | 7,8:1 | bouton principal |
| blanc #FFFFFF | `accent-survol` | 10,8:1 | bouton principal survolé |
| `texte-secondaire` | `separateur` | 5,2:1 | créneau indisponible uniquement |

`separateur` ne délimite jamais un élément interactif : c'est le rôle de
`bordure`, qui respecte 3:1. Le couple `texte-secondaire` sur `separateur` est
réservé aux créneaux indisponibles ; il passe AA (5,2:1), et WCAG dispense de
toute façon les éléments inactifs du seuil de contraste.

## 3. Typographie

- Titres : **Newsreader**. Texte : **Figtree**. Les deux chargées via
  `next/font`, hébergées avec le site (aucun appel à Google à l'affichage).
- Échelle : 16 / 18 / 22 / 28 / 36 px. Rien sous 16 px (BNF-10).
- Interligne : 1,5.
- Chiffres à chasse fixe (`tabular-nums`) sur les créneaux, les durées et les
  prix, pour que les colonnes restent alignées.

## 4. Composants et mise en page

- Conception à 360 px d'abord, puis élargissement (BNF-10).
- Coins arrondis de 8 px ; ombres quasi absentes (une bordure ou le contraste
  `fond` / `surface` suffit). Seule exception, l'arrondi `pastille` (#55,
  `rounded-pastille`) : statut d'une réservation, onglet courant, marque de
  réussite.
- Boutons : 48 px de haut. Zones tactiles d'au moins 44 × 44 px.
- **Focus clavier** : contour `accent` de 2 px, décalé de 2 px
  (`outline-offset`), sur tout élément interactif.
- **Bouton principal** : fond `accent`, texte blanc ; survol `accent-survol`.
- **Bouton secondaire** : fond `surface`, bordure `bordure`, texte `texte`.
- **Pas de bouton désactivé dans le parcours.** « Confirmer » reste actif : au
  clic, on affiche ce qui manque (message en `erreur` près du champ concerné).
- **Champ de saisie** : fond `surface`, bordure `bordure` de 1 px, libellé
  toujours visible au-dessus. Placeholder en `texte-secondaire` : c'est du
  texte, seuil 4,5:1 (jamais la transparence par défaut). En erreur : bordure
  de 2 px et message en `erreur`.
- **Carte** : fond `surface`, coins 8 px, bordure `separateur` ou aucune.
- **Carte cliquable** (ex. sélection d'une prestation, #5) : bordure `bordure`
  (3:1), jamais `separateur`, car elle délimite un élément interactif.
- **Bouton en chargement** : reste actif et focusable (pas de `disabled`), mais
  ignore les clics, Entrée et Espace tant que le chargement dure ; libellé de
  chargement et `aria-busy`.
- **Navigation** (#53, `components/navigation/navigation-site.tsx`) : trois
  destinations, Accueil, Réserver, Mes réservations.
  - **Téléphone (moins de 768 px)** : barre d'onglets fixe en bas, fond
    `surface`, filet `separateur` en haut ; chaque onglet a une icône au trait
    de 24 px et son libellé de 16 px, sur au moins 64 px de haut. Onglet
    courant (#55) : texte et icône `accent`, gras, pastille `separateur`
    derrière l'icône ; les autres en `texte-secondaire`, `texte` au survol.
    La barre tient compte de la zone système du bas (safe area) et la page
    réserve sa hauteur : rien n'est masqué dessous.
  - **Ordinateur (768 px et plus)** : en-tête fond `surface`, filet
    `separateur` en bas, logo « Salon RDV » vers l'accueil (#55) et les mêmes
    liens à droite. Liens sans soulignement : au repos `texte`, au survol fond
    `separateur` et texte `accent` (6:1) ; lien courant `accent` avec un trait
    `accent` de 2 px dessous.
  - Onglet ou lien courant signalé aussi par `aria-current="page"` ; icônes
    décoratives (`aria-hidden`).
- **Lien secondaire** (#55, `lienSecondaire` dans `components/ui/styles.ts`) :
  « Retour à l'accueil », « Changer de compte », « Changer d'e-mail… ». Texte
  `accent` en gras, sans soulignement au repos, souligné au survol, zone
  tactile de 44 px.
- **« ‹ Retour »** (`components/ui/lien-retour.tsx`) : en haut de chaque étape
  du parcours (et de « Mes réservations »), même place et même libellé
  visible ; lien secondaire avec un chevron, vers l'étape précédente (et non
  l'historique), nom complet pour les lecteurs d'écran (« Retour aux
  créneaux »).
- **Logo « Salon RDV »** (#55, `components/marque/logo-salon-rdv.tsx`) :
  Newsreader 500, couleur `accent`, en tracés (aucune police à charger). En
  tête du site sur ordinateur ; le nom du salon reste le titre de l'accueil.
  - **Favicon** (`app/favicon.ico`, `app/icon.svg`) : « S » `accent` sur fond
    `fond`, graisse renforcée (Newsreader 700, taille optique 12) pour rester
    lisible à 16 px.
  - **Icône de l'app pro** (`pro/assets/icone/`, et `app/apple-icon.png` pour
    le site) : « S » blanc sur fond `accent` ; icône adaptative Android avec
    le « S » en premier plan, même proportion visible que l'icône pleine.
- **Prestation** (écran 1) : nom en gras, durée en `texte-secondaire`, prix en
  gras, chevron `accent` à droite.
- **Bande de jours** (écran 2) : mois au-dessus (« Octobre – novembre 2026 »),
  repère « nov. » devant le 1er d'un nouveau mois (décoratif).
- **Réservation confirmée** : coche blanche dans un rond `accent` au-dessus du
  titre (décorative).
- **Statut d'une réservation** : pastille, bordure et texte `accent` si
  confirmée, `bordure` et `texte-secondaire` sinon.

## 5. Parcours de réservation (BNF-9 : 3 écrans hors authentification)

1. **Prestation** : liste des prestations (§7), sur l'accueil (depuis #129)
   ou sur l'écran `/reserver` (onglet « Réserver »).
2. **Créneau** : créneaux libres par jour. Le choix du coiffeur est un filtre
   sur cet écran, « Peu importe » par défaut. Depuis #130 (option A de
   Sparta), les heures du jour sont rangées sous « Matin » (avant 12:00),
   « Après-midi » (12:00 à 17:59) et « Soir » (à partir de 18:00), intertitres
   en texte secondaire gras ; tout reste visible (pas de « Voir plus
   d'horaires » comme chez Doctolib, qui cache des heures) ; un moment sans
   créneau n'apparaît pas. Survol d'une heure : bordure et chiffres `accent`.
3. **Confirmation** : récapitulatif (prestation, coiffeur, date, heure, prix).

- « Retour » ramène là d'où vient le client (#129, comme Planity ou
  Doctolib) : prestation choisie sur l'accueil → l'écran 2 revient à la liste
  de l'accueil (`depuis=accueil` gardé dans l'adresse jusqu'à l'écran 3) ;
  choisie sur l'écran 1 ou par un lien partagé → l'écran 1.
- Aucune connexion pour parcourir les écrans 1 et 2.
- **Connexion à l'écran 3 seulement, par code à 6 chiffres envoyé par e-mail
  (OTP), sans mot de passe ni lien magique** : le client saisit son e-mail,
  reçoit le code et le tape sur le même écran, sans quitter le site.
- Avant d'enregistrer, la disponibilité est revérifiée. Si le créneau vient
  d'être pris : message clair, et retour aux créneaux sans perdre la prestation
  choisie.
- Le gérant et l'app pro gardent la connexion par e-mail et mot de passe.

## 6. Accueil

- Une photo de démonstration, remplaçable par celle du salon : **vraie photo
  d'intérieur de salon**, pas de mannequin posé. Libre de droits (Unsplash),
  choisie à l'étape 2 avec l'accord de Sparta ; sa source sera citée ici.
- Sous la photo, sur fond uni : un titre court et un seul bouton « Réserver ».
- Jamais de texte posé sur la photo.

Photo retenue : [fauteuil de barbier, meuble en bois et miroir rond](https://unsplash.com/photos/barber-chair-in-modern-salon-workspace-N15dzf3dAUk),
par [Stefan Vibes](https://unsplash.com/@eusuntvibes) sur Unsplash ([licence
Unsplash](https://unsplash.com/license) : usage gratuit, modification permise).
Recadrée en 4:3, centrée sur le fauteuil et le miroir, écran de télévision
exclu : zone de 2400 × 1800 px à partir de la ligne 1490 de l'original
2400 × 3600, exportée en `web/public/accueil-salon.webp` (1600 × 1200, WebP).

Depuis #117, la photo envoyée par le gérant dans l'app pro (#105) remplace
cette photo de démonstration, recadrée en 4:3 de la même façon (centrée,
`object-cover`). Sans photo du gérant, ou si elle ne se charge pas, la photo
de démonstration reste affichée.

Depuis #129 (option A de Sparta, comme Planity ou Fresha), l'accueil montre
aussi ce que le client cherche avant de réserver, sous le titre :
- l'adresse du salon (icône de repère, texte secondaire), puis le lien
  secondaire « Itinéraire » aligné sous l'adresse, vers Google Maps ;
  rien si l'adresse est vide ;
- après les boutons, la section « Prestations » : la même liste que
  l'écran 1 (§7), un toucher mène aux créneaux de la prestation ; rien si
  aucune prestation n'est active. Le bouton « Réserver » descend jusqu'à
  cette liste (lien `#prestations`, défilement doux sauf si l'utilisateur
  demande moins d'animations), comme « Prendre RDV » chez Planity : on ne
  revoit pas la même liste sur une autre page (option A de Sparta) ;
- le téléphone du salon (réglé par le gérant dans l'app pro), en lien
  secondaire avec une icône de combiné : un toucher lance l'appel (`tel:`) ;
  rien sans numéro. Le même lien « Appeler le salon » suit le message de
  « Mes réservations » quand le délai d'annulation est passé ;
- en bas, la section « Horaires » : les sept jours du lundi au dimanche, comme
  Google Maps, jour à gauche et heures à droite (chiffres tabulaires), filet
  entre les lignes, « Fermé » en texte secondaire ; rien si aucun coiffeur
  n'a d'horaires. Règle : `horaires_du_salon()`, la même que l'onglet Salon de
  l'app pro (de la première arrivée au dernier départ des coiffeurs).
Le bouton principal reste unique.

## 7. Cartes de prestations

- Contenu : nom, durée, prix.
- Depuis #129 (remarque de Sparta : cartes encadrées trop « carrées ») : une
  ligne de liste **sans cadre**, filets fins `separateur` entre les lignes,
  comme la liste des horaires. Nom en gras (18 px) ; dessous la durée en texte
  secondaire, « · », puis le prix exact en gras (jamais « à partir de ») ;
  bouton « Choisir » à droite (bordure `bordure`, texte `accent`, 44 px de
  haut). Toute la ligne est le lien ; survol : la ligne garde son
  fond, « Choisir » se remplit (fond `accent`, texte `surface`), sans rien qui
  déborde des filets. Un nom long
  passe à la ligne, « Choisir » garde sa place.
- Comparé à Planity (même modèle : nom, durée, prix, « Choisir ») : pas de
  prix « à partir de » ou « sur devis », pas de ligne non réservable avec un
  bouton « Choisir », téléphone et horaires sur la même page que la liste.
- Photo facultative : la carte doit être réussie sans photo, qui est le cas
  normal en v1.
- Pas de stockage d'images en v1, sauf la photo d'accueil, fichier statique du
  site.

## 8. Références

- [Planity](https://www.planity.com) : ambiance sobre et contrastée.
- [Fresha](https://www.fresha.com) : catalogue de prestations en cartes.

Sources d'inspiration, pas des modèles à reproduire.

## 9. Mise en œuvre (`web/`)

- Jetons : `web/app/globals.css` (`@theme`). Les valeurs par défaut de Tailwind
  (couleurs, tailles de texte, arrondis, ombres, polices) sont désactivées.
- Composants : `web/components/ui/` (`Bouton`, `BoutonLien`, `Champ`, `Carte`).
- Garde-fou : `npm run lint` lance `web/scripts/verifier-charte.mjs`, qui échoue
  si `app/` ou `components/` contient un code hexadécimal, une classe de palette
  brute (`zinc-500`, `text-white`…), une taille de texte hors charte
  (`text-sm`…), une ombre, un arrondi autre que `rounded-base` ou `dark:`.
- Contrastes : `web/lib/charte.test.ts` vérifie que les jetons de
  `globals.css` sont ceux de ce document et que chaque couple du §2 atteint son
  seuil WCAG 2.2 AA.
- Vitrine : la page `/charte` affiche jetons et composants, en local et sur les
  previews Vercel ; elle répond 404 en production.

### App pro (`pro/`, #8)

La même charte, traduite en `ThemeData` Flutter pour que l'app pro ressemble
au site :

- Jetons : `pro/lib/ui/charte.dart`. Il contient les couleurs (`Couleurs`),
  l'échelle de texte (`Tailles` : 16 / 18 / 22 / 28 / 36 px, interligne 1,5),
  les espacements sur la grille de 4 px du site (`Espaces`), les coins de
  8 px et les boutons de 48 px.
- Polices : Newsreader (titres, graisse 500) et Figtree (texte 400,
  libellés et boutons 600), embarquées dans `pro/assets/fonts/`.
- Correspondance avec les composants du site :
  - `FilledButton` : bouton principal ;
  - `OutlinedButton` : bouton secondaire ;
  - `TextButton` : lien souligné ;
  - `InputDecorationTheme` : champ (bordure de 1 px, 2 px au focus et en
    erreur) ;
  - `CardTheme` : carte (bordure `separateur`, sans ombre).
- Pas de teinte ni d'ombre Material 3 (`surfaceTint` et `shadow`
  transparents). Focus clavier : contour `accent` de 2 px.
- Composants Flutter : `pro/lib/ui/composants.dart`. `Champ` place le libellé
  au-dessus du champ. `Bouton` n'est jamais désactivé : pendant le
  chargement, il ignore les appuis.
- Garde-fou : `pro/test/ui/charte_test.dart` vérifie que les couleurs et les
  tailles sont celles de `web/app/globals.css`, et que chaque couple du §2
  atteint son seuil WCAG 2.2 AA.
- Identité (#41) :
  - **logo « Salon RDV »** (`pro/lib/ui/marque.dart`, `LogoSalonRdv`) :
    Newsreader 500, taille optique 36, couleur `accent`, comme sur le site.
    En grand (36 px) en tête de la connexion, sans barre du haut ; à gauche
    de la barre du haut (22 px) sur le choix d'espace et l'accès refusé ; en
    tête de l'onglet Compte. Lu « Salon RDV ».
  - **écran de démarrage** : fond `fond` et icône de l'app (« S » blanc sur
    `accent`) au centre, sans logo Flutter. Android :
    `res/drawable*/launch_background.xml`, et `res/values*-v31/styles.xml`
    pour l'écran de démarrage du système (Android 12 et plus). Web :
    `pro/web/index.html`, retiré à la première image de Flutter.
- **Barre d'onglets** (#64, lot 1 de la refonte ; remplace le menu du
  compte de #41) : Aujourd'hui, Planning, Salon, Compte, en bas de chaque
  espace, comme celle du site sur téléphone : fond `surface`, filet
  `separateur` au-dessus, onglet courant en `accent` et gras avec une
  pastille `separateur` derrière l'icône, les autres en `texte-secondaire`,
  libellés de 16 px. Toujours visible, sans défiler, à 360 × 640.
  - **Aujourd'hui** : date et espace en petit, titre éditorial en
    Newsreader 36 px (« Bonjour Amira, 6 clients aujourd'hui ») ; bandeau
    `accent` du rendez-vous en cours ; grande carte du prochain rendez-vous
    (heure en Newsreader 44 px, « dans 2 h 40 ») ; chiffres du jour :
    terminés, absents, restants, dont la somme est le total du titre (en
    cours compris) ; pour le gérant, encaissé du jour sur fond `accent` et
    nombre à encaisser ; puis les rendez-vous du jour.
  - **Planning** : frise horaire (heures hors horaires grisées, trait
    « maintenant » en `erreur`), blocs colorés par état ; le gérant choisit
    le coiffeur par des pastilles.
  - **Salon** : gérant, historique, prestations et équipe ; coiffeur, ses
    horaires et ses absences des 30 prochains jours, en lecture seule.
  - **Compte** : logo, compte connecté et rôle, choix de l'espace (gérant qui
    est aussi coiffeur, boutons segmentés), « Se déconnecter ».
- **États d'un rendez-vous** (`CouleursStatut`, `StyleEtat`) : un fond
  différent par état (vérifié par `pro/test/ui/charte_test.dart`), libellé
  en toutes lettres doublé d'une icône, jamais la couleur seule ; sur un bloc
  trop court pour deux lignes, l'icône précède l'heure.

  | État | Fond | Libellé |
  | --- | --- | --- |
  | À venir | `surface`, bordure `accent` | `accent` |
  | Arrivé (client arrivé avant l'heure, #102) | `#D3DEDB`, bordure `accent` | `accent` |
  | En cours | `accent` | blanc |
  | À clôturer (fini, pas encore clôturé) | `#FCEFD6`, bordure `#A35A00` (4,6:1) | `#8A4B00` (6:1) |
  | Terminé | `#EFEDE8` | `texte-secondaire` (5,7:1) |
  | Absent | `#FBEAE8` | `#8F1D13` (7,7:1) |

- **Gestes** (« Aujourd'hui ») : sur un rendez-vous commencé, glisser à
  droite révèle une coche et « Terminé » sur un vert foncé plein `#0B3325`
  (blanc 13,9:1), à gauche « Client absent » sur un rouge foncé plein
  `#7A1A10` (blanc 10,6:1) : couleurs d'action, distinctes des fonds des
  états (le vert est plus foncé que l'`accent` du rendez-vous en cours). Petite vibration au seuil, vibration de
  confirmation au geste. Message bref « Annuler » : l'enregistrement part au
  bout de 5 s, ou tout de suite si l'on quitte l'onglet ou l'app. Au premier
  usage (une fois par lancement), la première carte glissable glisse un peu
  pour montrer le geste, sauf si le téléphone demande moins d'animations.
  Les deux clôtures sont aussi des actions TalkBack du rendez-vous, et
  restent dans sa fiche.
- Hiérarchie : titre d'écran dans la barre du haut (Newsreader 22 px), ou
  titre d'onglet en Newsreader 36 px ; sections en Figtree 16 px gras
  `texte-secondaire` ; marges latérales de 16 px. Un seul bouton principal
  par écran ; les choix de même poids sont des boutons secondaires.
- Accessibilité : `pro/test/ui/accessibilite_test.dart` passe chaque écran
  aux contrôles de Flutter, à 360 × 640 : zones tactiles d'au moins 48 px,
  éléments interactifs libellés, contraste du texte (WCAG 2.2 AA).

## 10. Captures

| | 360 px | 1280 px |
| --- | --- | --- |
| Accueil | ![Accueil à 360 px](captures/accueil-360.webp) | ![Accueil à 1280 px](captures/accueil-1280.webp) |
| Vitrine `/charte` | ![Charte à 360 px](captures/charte-360.webp) | ![Charte à 1280 px](captures/charte-1280.webp) |

Focus clavier sur le bouton « Réserver » (contour accent 2 px, décalé de 2 px) :

![Focus du bouton à 360 px](captures/focus-bouton-360.webp)


### Refonte du site client (#55)

Avant et après, à 360 px (site construit sur la base locale) :

| Écran | Avant | Après |
| --- | --- | --- |
| Accueil | ![Accueil avant](captures/refonte/tel-1-accueil-avant.webp) | ![Accueil après](captures/refonte/tel-1-accueil-apres.webp) |
| Prestations | ![Prestations avant](captures/refonte/tel-2-prestations-avant.webp) | ![Prestations après](captures/refonte/tel-2-prestations-apres.webp) |
| Créneaux | ![Créneaux avant](captures/refonte/tel-3-creneaux-avant.webp) | ![Créneaux après](captures/refonte/tel-3-creneaux-apres.webp) |
| Confirmation | ![Confirmation avant](captures/refonte/tel-4-confirmation-avant.webp) | ![Confirmation après](captures/refonte/tel-4-confirmation-apres.webp) |
| Réservation confirmée | ![Confirmée avant](captures/refonte/tel-5-confirmee-avant.webp) | ![Confirmée après](captures/refonte/tel-5-confirmee-apres.webp) |
| Mes réservations | ![Mes réservations avant](captures/refonte/tel-6-mes-reservations-avant.webp) | ![Mes réservations après](captures/refonte/tel-6-mes-reservations-apres.webp) |

Sur ordinateur (1366 px) :

| Écran | Avant | Après |
| --- | --- | --- |
| Prestations | ![Prestations avant](captures/refonte/pc-1-prestations-avant.webp) | ![Prestations après](captures/refonte/pc-1-prestations-apres.webp) |
| Créneaux | ![Créneaux avant](captures/refonte/pc-2-creneaux-avant.webp) | ![Créneaux après](captures/refonte/pc-2-creneaux-apres.webp) |

En-tête : « Accueil » au repos, « Réserver » page courante, « Mes réservations » survolé.

![États de l'en-tête](captures/refonte/pc-3-entete-etats-apres.webp)

### App pro (#41)

Navigateur (Chrome), 360 × 640 : version web de l'app construite sur la base
locale, pilotée par le Playwright du site. Entre les deux séries, des données
de la base locale ont changé (démonstration en cours) : prestations,
absences.

| Écran | Avant | Après |
| --- | --- | --- |
| Connexion | ![Connexion avant](captures/app-pro/navigateur/01-connexion-avant.webp) | ![Connexion après](captures/app-pro/navigateur/01-connexion-apres.webp) |
| Connexion, champs manquants | ![Connexion, champs manquants avant](captures/app-pro/navigateur/02-connexion-erreurs-avant.webp) | ![Connexion, champs manquants après](captures/app-pro/navigateur/02-connexion-erreurs-apres.webp) |
| Accès refusé (client) | ![Accès refusé (client) avant](captures/app-pro/navigateur/03-acces-refuse-avant.webp) | ![Accès refusé (client) après](captures/app-pro/navigateur/03-acces-refuse-apres.webp) |
| Choix de l'espace | ![Choix de l'espace avant](captures/app-pro/navigateur/04-choix-espace-avant.webp) | ![Choix de l'espace après](captures/app-pro/navigateur/04-choix-espace-apres.webp) |
| Accueil, gérant et coiffeur | ![Accueil, gérant et coiffeur avant](captures/app-pro/navigateur/05-accueil-gerant-et-coiffeur-avant.webp) | ![Accueil, gérant et coiffeur après](captures/app-pro/navigateur/05-accueil-gerant-et-coiffeur-apres.webp) |
| Accueil coiffeur | ![Accueil coiffeur avant](captures/app-pro/navigateur/06-accueil-coiffeur-avant.webp) | ![Accueil coiffeur après](captures/app-pro/navigateur/06-accueil-coiffeur-apres.webp) |
| Mon planning, jour | ![Mon planning, jour avant](captures/app-pro/navigateur/07-mon-planning-jour-avant.webp) | ![Mon planning, jour après](captures/app-pro/navigateur/07-mon-planning-jour-apres.webp) |
| Mon planning, semaine | ![Mon planning, semaine avant](captures/app-pro/navigateur/08-mon-planning-semaine-avant.webp) | ![Mon planning, semaine après](captures/app-pro/navigateur/08-mon-planning-semaine-apres.webp) |
| Accueil gérant | ![Accueil gérant avant](captures/app-pro/navigateur/09-accueil-gerant-avant.webp) | ![Accueil gérant après](captures/app-pro/navigateur/09-accueil-gerant-apres.webp) |
| Planning de l'équipe | ![Planning de l'équipe avant](captures/app-pro/navigateur/10-planning-equipe-avant.webp) | ![Planning de l'équipe après](captures/app-pro/navigateur/10-planning-equipe-apres.webp) |
| Fiche d'un rendez-vous | ![Fiche d'un rendez-vous avant](captures/app-pro/navigateur/11-fiche-rendez-vous-avant.webp) | ![Fiche d'un rendez-vous après](captures/app-pro/navigateur/11-fiche-rendez-vous-apres.webp) |
| Rendez-vous terminé | ![Rendez-vous terminé avant](captures/app-pro/navigateur/12-fiche-terminee-avant.webp) | ![Rendez-vous terminé après](captures/app-pro/navigateur/12-fiche-terminee-apres.webp) |
| Encaissement | ![Encaissement avant](captures/app-pro/navigateur/13-encaissement-avant.webp) | ![Encaissement après](captures/app-pro/navigateur/13-encaissement-apres.webp) |
| Historique | ![Historique avant](captures/app-pro/navigateur/14-historique-avant.webp) | ![Historique après](captures/app-pro/navigateur/14-historique-apres.webp) |
| Prestations | ![Prestations avant](captures/app-pro/navigateur/15-prestations-avant.webp) | ![Prestations après](captures/app-pro/navigateur/15-prestations-apres.webp) |
| Nouvelle prestation | ![Nouvelle prestation avant](captures/app-pro/navigateur/16-nouvelle-prestation-avant.webp) | ![Nouvelle prestation après](captures/app-pro/navigateur/16-nouvelle-prestation-apres.webp) |
| Nouvelle prestation, erreurs | ![Nouvelle prestation, erreurs avant](captures/app-pro/navigateur/17-nouvelle-prestation-erreurs-avant.webp) | ![Nouvelle prestation, erreurs après](captures/app-pro/navigateur/17-nouvelle-prestation-erreurs-apres.webp) |
| Équipe | ![Équipe avant](captures/app-pro/navigateur/18-equipe-avant.webp) | ![Équipe après](captures/app-pro/navigateur/18-equipe-apres.webp) |
| Fiche coiffeur | ![Fiche coiffeur avant](captures/app-pro/navigateur/19-fiche-coiffeur-avant.webp) | ![Fiche coiffeur après](captures/app-pro/navigateur/19-fiche-coiffeur-apres.webp) |
| Nouvelle plage | ![Nouvelle plage avant](captures/app-pro/navigateur/20-nouvelle-plage-avant.webp) | ![Nouvelle plage après](captures/app-pro/navigateur/20-nouvelle-plage-apres.webp) |
| Fiche coiffeur, bas | ![Fiche coiffeur, bas avant](captures/app-pro/navigateur/21-fiche-coiffeur-bas-avant.webp) | ![Fiche coiffeur, bas après](captures/app-pro/navigateur/21-fiche-coiffeur-bas-apres.webp) |
| Nouvelle absence | ![Nouvelle absence avant](captures/app-pro/navigateur/22-nouvelle-absence-avant.webp) | ![Nouvelle absence après](captures/app-pro/navigateur/22-nouvelle-absence-apres.webp) |

Nouveaux : écran de démarrage, menu du compte.

| Démarrage | Menu du compte |
| --- | --- |
| ![Démarrage](captures/app-pro/navigateur/00-demarrage-apres.webp) | ![Menu du compte](captures/app-pro/navigateur/05b-menu-compte-apres.webp) |

Android (émulateur `Small_Phone`, Android 15, 360 × 640 dp, APK construit sur
la base locale, `be0a42c` avant et `main` après) :

| Écran | Avant | Après |
| --- | --- | --- |
| Écran de démarrage | ![Écran de démarrage avant](captures/app-pro/android/00-demarrage-avant.webp) | ![Écran de démarrage après](captures/app-pro/android/00-demarrage-apres.webp) |
| Connexion | ![Connexion avant](captures/app-pro/android/01-connexion-avant.webp) | ![Connexion après](captures/app-pro/android/01-connexion-apres.webp) |
| Connexion, champs manquants | ![Connexion, champs manquants avant](captures/app-pro/android/02-connexion-erreurs-avant.webp) | ![Connexion, champs manquants après](captures/app-pro/android/02-connexion-erreurs-apres.webp) |
| Accès refusé (client) | ![Accès refusé (client) avant](captures/app-pro/android/03-acces-refuse-avant.webp) | ![Accès refusé (client) après](captures/app-pro/android/03-acces-refuse-apres.webp) |
| Choix de l'espace | ![Choix de l'espace avant](captures/app-pro/android/04-choix-espace-avant.webp) | ![Choix de l'espace après](captures/app-pro/android/04-choix-espace-apres.webp) |
| Accueil, gérant et coiffeur | ![Accueil, gérant et coiffeur avant](captures/app-pro/android/05-accueil-gerant-et-coiffeur-avant.webp) | ![Accueil, gérant et coiffeur après](captures/app-pro/android/05-accueil-gerant-et-coiffeur-apres.webp) |
| Accueil coiffeur | ![Accueil coiffeur avant](captures/app-pro/android/06-accueil-coiffeur-avant.webp) | ![Accueil coiffeur après](captures/app-pro/android/06-accueil-coiffeur-apres.webp) |
| Mon planning, jour | ![Mon planning, jour avant](captures/app-pro/android/07-mon-planning-jour-avant.webp) | ![Mon planning, jour après](captures/app-pro/android/07-mon-planning-jour-apres.webp) |
| Accueil gérant | ![Accueil gérant avant](captures/app-pro/android/09-accueil-gerant-avant.webp) | ![Accueil gérant après](captures/app-pro/android/09-accueil-gerant-apres.webp) |
| Planning de l'équipe | ![Planning de l'équipe avant](captures/app-pro/android/10-planning-equipe-avant.webp) | ![Planning de l'équipe après](captures/app-pro/android/10-planning-equipe-apres.webp) |
| Historique | ![Historique avant](captures/app-pro/android/14-historique-avant.webp) | ![Historique après](captures/app-pro/android/14-historique-apres.webp) |
| Prestations | ![Prestations avant](captures/app-pro/android/15-prestations-avant.webp) | ![Prestations après](captures/app-pro/android/15-prestations-apres.webp) |
| Nouvelle prestation | ![Nouvelle prestation avant](captures/app-pro/android/16-nouvelle-prestation-avant.webp) | ![Nouvelle prestation après](captures/app-pro/android/16-nouvelle-prestation-apres.webp) |
| Équipe | ![Équipe avant](captures/app-pro/android/18-equipe-avant.webp) | ![Équipe après](captures/app-pro/android/18-equipe-apres.webp) |
| Fiche coiffeur | ![Fiche coiffeur avant](captures/app-pro/android/19-fiche-coiffeur-avant.webp) | ![Fiche coiffeur après](captures/app-pro/android/19-fiche-coiffeur-apres.webp) |
| Nouvelle plage | ![Nouvelle plage avant](captures/app-pro/android/20-nouvelle-plage-avant.webp) | ![Nouvelle plage après](captures/app-pro/android/20-nouvelle-plage-apres.webp) |
| Nouvelle absence | ![Nouvelle absence avant](captures/app-pro/android/22-nouvelle-absence-avant.webp) | ![Nouvelle absence après](captures/app-pro/android/22-nouvelle-absence-apres.webp) |

Menu du compte (nouveau) :

![Menu du compte](captures/app-pro/android/05b-menu-compte-apres.webp)

Écran de démarrage sur Android 15 (écran de démarrage du système) : avant,
l'icône sur fond blanc ; après, sur le fond de la charte (`#FAFAF7`), sans
logo Flutter, jusqu'à l'indicateur de chargement de l'app. Android 11 et
moins (`launch_background.xml`) : non vérifié, pas d'émulateur de cette
version.

### Refonte de l'app pro, lot 1 (#64)

Navigateur, 360 × 640, base locale (réservations du jour créées par les tests
de bout en bout du site). « Avant » : les captures de #41.

| Écran | Avant (#41) | Après |
| --- | --- | --- |
| Aujourd'hui (coiffeur) | ![Aujourd'hui (coiffeur) avant](captures/app-pro/navigateur/06-accueil-coiffeur-apres.webp) | ![Aujourd'hui (coiffeur) après](captures/app-pro/lot1/01-aujourdhui-coiffeur-lot1.webp) |
| Aujourd'hui, rendez-vous du jour | (nouveau) | ![Aujourd'hui, rendez-vous du jour après](captures/app-pro/lot1/02-aujourdhui-coiffeur-liste-lot1.webp) |
| Aujourd'hui (gérant) | ![Aujourd'hui (gérant) avant](captures/app-pro/navigateur/09-accueil-gerant-apres.webp) | ![Aujourd'hui (gérant) après](captures/app-pro/lot1/07-aujourdhui-gerant-lot1.webp) |
| Planning (coiffeur) | ![Planning (coiffeur) avant](captures/app-pro/navigateur/07-mon-planning-jour-apres.webp) | ![Planning (coiffeur) après](captures/app-pro/lot1/03-planning-coiffeur-lot1.webp) |
| Planning, terminés | (nouveau) | ![Planning, terminés après](captures/app-pro/lot1/04-planning-coiffeur-hier-lot1.webp) |
| Planning de l'équipe | ![Planning de l'équipe avant](captures/app-pro/navigateur/10-planning-equipe-apres.webp) | ![Planning de l'équipe après](captures/app-pro/lot1/08-planning-equipe-lot1.webp) |
| Planning de l'équipe, un autre coiffeur | (nouveau) | ![Planning de l'équipe, un autre coiffeur après](captures/app-pro/lot1/09-planning-equipe-hier-youssef-lot1.webp) |
| Salon (gérant) | ![Salon (gérant) avant](captures/app-pro/navigateur/09-accueil-gerant-apres.webp) | ![Salon (gérant) après](captures/app-pro/lot1/10-salon-gerant-lot1.webp) |
| Salon (coiffeur) | (nouveau) | ![Salon (coiffeur) après](captures/app-pro/lot1/05-salon-coiffeur-lot1.webp) |
| Compte (coiffeur) | ![Compte (coiffeur) avant](captures/app-pro/navigateur/05b-menu-compte-apres.webp) | ![Compte (coiffeur) après](captures/app-pro/lot1/06-compte-coiffeur-lot1.webp) |
| Compte (gérant et coiffeur) | ![Compte (gérant et coiffeur) avant](captures/app-pro/navigateur/05b-menu-compte-apres.webp) | ![Compte (gérant et coiffeur) après](captures/app-pro/lot1/11-compte-gerant-et-coiffeur-lot1.webp) |

Les cinq états, avec les rendez-vous de `supabase/demo/gestes-locaux.sql`
(terminé, absent, à clôturer, en cours, à venir), et les deux gestes à
mi-course (relâchés sans rien enregistrer) :

| Aujourd'hui | Rendez-vous du jour | Planning |
| --- | --- | --- |
| ![Aujourd'hui, états](captures/app-pro/lot1/12-aujourdhui-etats-lot1.webp) | ![Rendez-vous du jour, cinq états](captures/app-pro/lot1/13-aujourdhui-liste-etats-lot1.webp) | ![Planning, cinq états](captures/app-pro/lot1/15-planning-etats-lot1.webp) |

| Geste vers la droite : « Terminé » | Geste vers la gauche : « Client absent » |
| --- | --- |
| ![Geste vers la droite](captures/app-pro/lot1/14-geste-termine-lot1.webp) | ![Geste vers la gauche](captures/app-pro/lot1/14b-geste-absent-lot1.webp) |

## 11. Formulaires de l'app pro (#41)

Règles communes à tous les formulaires de `pro/`, appliquées par `Champ`
(`pro/lib/ui/composants.dart`) et vérifiées par `pro/test/features/` et
`pro/test/ui/champ_semantique_test.dart`.

- **Libellé** au-dessus du champ, toujours visible, repris sur le nœud du
  champ pour TalkBack ; « (facultatif) » dans le libellé si le champ peut
  rester vide ; l'unité aussi : « Prix (DT) », « Durée (minutes) ».
- **Exemple sous le champ** (`aide`) quand le format n'est pas évident :
  « Exemple : 35 ou 10,500 » (prix, montant), « Exemple : 45 » (durée),
  « Exemple : congé, formation » (motif). Texte secondaire, 16 px, lu après
  le libellé ; remplacé par le message d'erreur quand il y en a un.
- **Claviers** : e-mail pour une adresse, décimal pour un prix ou un
  montant, numérique pour un nombre entier ; majuscule en début de phrase
  pour un nom ou un motif ; ni correction ni suggestion sur l'e-mail et le
  mot de passe.
- **Touche Entrée** : « Suivant » passe au champ suivant ; sur le dernier
  champ, « OK » fait la même chose que le bouton principal.
- **Sélecteurs** :
  - date : bouton qui affiche la date choisie et ouvre le calendrier ;
  - heure : bouton de 104 px qui affiche l'heure (24 h) et ouvre le
    sélecteur d'heure ;
  - un choix parmi deux ou trois options toujours visibles (vue Jour ou
    Semaine, période de l'historique) : boutons segmentés, de même largeur ;
  - un choix dans une liste plus longue (jour de la semaine, coiffeur) :
    liste déroulante, avec son libellé lu par TalkBack (« Jour, Lundi ») ;
  - plusieurs choix indépendants (compétences) : cases à cocher, enregistrées
    aussitôt ;
  - boutons de sélection d'un même formulaire à la même largeur (date sur la
    largeur restante, heure sur 104 px) ; libellé lu « Début, heure : 09:00,
    modifier ».
- **Validation** : le bouton principal n'est jamais désactivé ; au clic, ce
  qui manque est signalé sous le champ concerné, en `erreur`, sur un ton
  commun : « Indiquez … » (« Indiquez le nom de la prestation. »), avec un
  exemple si le format est en cause. Erreur de la base : message sous le
  formulaire, au-dessus du bouton, lu par TalkBack.
- **Confirmation** : après chaque enregistrement, un message bref
  (SnackBar) dit ce qui a été fait : « Prestation ajoutée. », « Plage
  ajoutée : Lundi 09:00 – 18:00. », « Compétence ajoutée : Couleur. »,
  « Encaissement enregistré. ».
- **Chargement et erreur** : mêmes états partout (`Chargement`,
  `pro/lib/ui/chargement.dart`) : indicateur `accent` centré, puis message
  en `erreur` et bouton secondaire « Réessayer ». Pendant un enregistrement,
  le bouton garde sa place et affiche « Enregistrement… ».

Formulaires vérifiés (#41) : connexion ; prestation (création,
modification) ; encaissement (et correction du montant) ; nouvelle plage ;
nouvelle absence ; compétences ; filtres de l'historique ; vue de « Mon
planning ».
