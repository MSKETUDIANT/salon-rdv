# Cahier des charges — Gestionnaire de rendez-vous de salon de coiffure

Oct 22, 2026 · @msk

## 1. Contexte et objectifs

L'application permet aux clients d'un salon de coiffure de réserver à l'avance, et au gérant de voir et d'organiser l'activité de son équipe. C'est un projet d'apprentissage : l'objectif est de couvrir toutes les étapes du métier, du besoin à l'exploitation.

Le problème a deux faces :

- **Côté client** : il perd du temps à attendre au salon, faute de pouvoir réserver un créneau à l'avance.
- **Côté gérant** : il n'a aucune visibilité sur l'activité à venir, donc il ne peut ni s'organiser ni répartir la charge entre ses coiffeurs.

Objectifs :

1. Supprimer l'attente non prévue du client.
2. Donner au gérant une vue claire du planning de toute l'équipe.
3. Garder un historique des prestations réalisées et des encaissements.

## 2. Acteurs et rôles

Une personne n'est pas un rôle : un même utilisateur peut cumuler plusieurs rôles. Le gérant peut aussi être coiffeur, ce qui couvre aussi bien le coiffeur indépendant que le salon avec une équipe.

| Rôle | Qui | Ce qu'il fait |
| --- | --- | --- |
| Client | Personne qui veut se faire coiffer | Consulte, réserve, annule |
| Coiffeur | Membre de l'équipe | Suit son planning, clôture ses rendez-vous |
| Gérant | Responsable du salon | Configure le salon, gère l'équipe, enregistre les encaissements |

C'est le rôle de gérant qui autorise la modification des horaires et des absences.

## 3. Périmètre

La version 1 couvre **un seul salon**, dans **une seule application** utilisable sur mobile et sur ordinateur, qui affiche l'espace adapté au rôle de l'utilisateur.

La base de données est pensée dès le départ pour évoluer : chaque donnée est rattachée à un salon.

**Hors périmètre (évolutions possibles) :**

- Plateforme multi-salons, avec un compte client unique pour tous les salons.
- Paiement en ligne : en v1, le client paie au salon et le gérant note le montant.
- Demandes de congés avec validation : la gestion des absences reste humaine, le gérant les saisit directement.

Le choix de la technologie n'est pas fait ici : il relève de l'étape de conception.

## 4. Besoins fonctionnels

| Id | Acteur | Le système doit permettre de… |
| --- | --- | --- |
| BF-C1 | Client | Voir les créneaux disponibles sans avoir de compte |
| BF-C2 | Client | Choisir une prestation |
| BF-C3 | Client | Choisir un coiffeur parmi ceux qui savent faire la prestation choisie |
| BF-C4 | Client | Se connecter ou créer un compte au moment de réserver |
| BF-C5 | Client | Réserver un créneau |
| BF-C6 | Client | Consulter et annuler sa réservation |
| BF-K1 | Coiffeur | Voir son planning par jour et par semaine |
| BF-K2 | Coiffeur | Voir le détail de ses réservations |
| BF-K3 | Coiffeur | Marquer un rendez-vous comme terminé, ce qui alimente l'historique |
| BF-K4 | Coiffeur | Marquer un client comme absent |
| BF-G1 | Gérant | Gérer les horaires et les absences des coiffeurs |
| BF-G2 | Gérant | Gérer le catalogue de prestations : nom, prix, durée |
| BF-G3 | Gérant | Indiquer quelles prestations chaque coiffeur sait faire |
| BF-G4 | Gérant | Enregistrer l'encaissement d'un rendez-vous (montant payé au salon) |
| BF-G5 | Gérant | Voir le planning de toute l'équipe d'un coup d'œil |

**Règle de gestion centrale** : un créneau proposé doit avoir la durée de la prestation, tomber dans les horaires du coiffeur, hors de ses absences, et ne chevaucher aucune autre réservation.

## 5. Besoins non fonctionnels

Les huit critères de l'ISO 25010 ont été confrontés au contexte du salon : clients sur mobile, réseau parfois faible, téléphones modestes, gérant peu à l'aise avec la technique. L'utilisabilité est précisée par trois exigences d'ergonomie (BNF-9 à BNF-11). **Les seuils sont des propositions à valider.**

| Id | Critère | Priorité | Exigence mesurable | Comment on teste |
| --- | --- | --- | --- | --- |
| BNF-1 | Fiabilité | Haute | Zéro double réservation, même si deux clients valident le même créneau à la même seconde | Test automatisé de réservations simultanées |
| BNF-2 | Adéquation fonctionnelle | Haute | 100 % des créneaux proposés respectent la règle de gestion centrale | Tests automatisés sur des plannings types |
| BNF-3 | Sécurité | Haute | Un client ne voit que ses réservations ; seul le gérant modifie horaires, absences et catalogue | Tests d'accès par rôle + scan de failles |
| BNF-4 | Utilisabilité | Haute | Un nouveau client réserve en moins de 2 minutes, sans aide | 5 vrais utilisateurs, chronométrés |
| BNF-5 | Performance | Moyenne | Liste des créneaux affichée en moins de 3 s sur un téléphone d'entrée de gamme en 3G | Mesure sur réseau bridé |
| BNF-6 | Maintenabilité | Moyenne | Code séparé en modules ; règles de réservation couvertes par des tests automatisés | Revue de code + couverture des tests |
| BNF-7 | Portabilité | Basse | Fonctionne sur un navigateur d'ordinateur et sur Android | Test manuel sur les deux |
| BNF-8 | Compatibilité | Basse | Pas d'interopérabilité exigée en v1 | — |
| BNF-9 | Utilisabilité | Haute | Une réservation tient en 3 écrans maximum, de l'accueil à la confirmation, hors authentification | Parcours automatisé (Playwright) qui compte les écrans traversés, écrans d'authentification exclus |
| BNF-10 | Utilisabilité | Haute | Mobile-first : chaque écran est conçu d'abord pour 360 px de large, sans défilement horizontal, avec des zones tactiles d'au moins 44 × 44 px et un texte de base d'au moins 16 px | Tests automatisés à 360 px (largeur de page = largeur d'écran) + revue des écrans |
| BNF-11 | Utilisabilité | Haute | Contrastes conformes à WCAG 2.2 niveau AA : au moins 4,5:1 pour le texte normal, 3:1 pour le grand texte et les composants d'interface | Audit automatisé (axe-core, règle de contraste) sur chaque page du site client |

Compromis assumé : la sécurité ne doit pas alourdir la réservation, d'où la connexion demandée seulement au moment de réserver.

## 6. Contraintes

| Type | Contrainte |
| --- | --- |
| Technique | Réseau mobile parfois faible, téléphones modestes côté clients |
| Légale | Protection des données personnelles selon le pays du salon : loi L/2016/037 en Guinée, loi organique 2004-63 en Tunisie, RGPD si des clients sont européens |
| Délai | Deux semaines : l'IA écrit le code, le développeur comprend et vérifie tout |
| Budget | Services gratuits uniquement, projet d'apprentissage |

## 7. Livrables

- L'application déployée et accessible en ligne.
- Le code source versionné sur Git, **base de données comprise** (migrations).
- Les tests automatisés.
- Un README : installation, lancement, déploiement.

## 8. Planning

Cinq sprints de 2 à 3 jours, sur deux semaines. Le détail des tâches est dans le backlog GitHub (13 issues).

1. Sprint 1 — Base de données : projet Supabase et migrations, authentification et rôles par salon, règles d'accès (RLS).
2. Sprint 2 — Site client Next.js : initialisation et déploiement Vercel, créneaux sans compte (BF-C1 à C3), connexion et réservation (BF-C4, C5), consultation et annulation (BF-C6).
3. Sprint 3 — App pro Flutter : initialisation, configuration du salon (BF-G1 à G3), plannings (BF-K1, K2, BF-G5).
4. Sprint 4 — Exploitation : clôture, absence et encaissement (BF-K3, K4, BF-G4).
5. Sprint 5 — Qualité et livraison : vérification des BNF-1 à BNF-11, README et mise en ligne.

Les tests s'écrivent dans chaque sprint, pas seulement au dernier.

## 9. Critères d'acceptation

Le projet est terminé et validé quand toutes ces cases sont cochées :

- [ ] Les 15 besoins fonctionnels marchent de bout en bout, chacun démontré.
- [ ] Les besoins non fonctionnels de priorité haute (BNF-1 à BNF-4, BNF-9 à BNF-11) passent leurs tests.
- [ ] Les priorités moyennes et basses sont mesurées, et les écarts expliqués.
- [ ] Les migrations locales et distantes sont synchronisées, vérifiées soi-même.
- [ ] L'application tourne en ligne, et le README permet à quelqu'un d'autre de l'installer.
