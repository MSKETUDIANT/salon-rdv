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

1. **Prestation** : catalogue en cartes.
2. **Créneau** : créneaux libres par jour. Le choix du coiffeur est un filtre
   sur cet écran, « Peu importe » par défaut.
3. **Confirmation** : récapitulatif (prestation, coiffeur, date, heure, prix).

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

## 7. Cartes de prestations

- Contenu : nom, durée, prix.
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
