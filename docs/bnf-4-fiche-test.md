# Fiche de test BNF-4 : réserver en moins de 2 minutes

**Exigence** (cahier des charges, BNF-4, priorité haute) : un nouveau client
réserve en moins de 2 minutes, sans aide. Vérification : 5 vrais
utilisateurs, chronométrés.

**Plan** :

- **Série 1** : Sparta, puis 2 ou 3 testeurs (après #7).
- **Série 2** : compléter jusqu'à 5 testeurs. C'est le critère de #12,
  sprint 5.

Fiche remplie par l'observateur, une ligne par testeur. Aucun nom : les
testeurs sont notés T1, T2…

## Conditions

- **Site de production** : https://salon-rdv-one.vercel.app
- **Le téléphone du testeur**, avec son navigateur habituel, en
  **navigation privée** (aucune session ni saisie déjà remplie).
- **Un nouveau client** : il n'a jamais réservé sur le site, et utilise une
  adresse e-mail à laquelle il a accès sur ce même téléphone.
- **Sans aide** : l'observateur ne répond à aucune question pendant le test.
  Si le testeur bloque plus de 30 secondes, ou demande de l'aide, on note
  « aide » et le test est **échoué**, même s'il finit en moins de 2 minutes.
- Réseau habituel du testeur (4G ou Wi-Fi), noté dans le tableau.

## Consigne à lire au testeur (mot pour mot)

> « Tu veux prendre rendez-vous pour une coupe dans ce salon. Ouvre le lien
> que je t'envoie et réserve un créneau de ton choix, avec ton adresse
> e-mail. Je ne peux pas t'aider pendant le test. Dis "c'est fini" quand tu
> penses avoir terminé. »

Ne pas montrer le site avant, ne pas expliquer le code reçu par e-mail.

## Chronométrage

- **Départ** : le testeur ouvre le lien de l'accueil (premier affichage de la
  page).
- **Arrivée** : l'écran « Réservation confirmée » s'affiche.
- Le temps d'attente de l'e-mail du code **compte** : un vrai client
  l'attendrait aussi. Si l'e-mail met plus de 30 secondes à arriver, le noter
  dans les observations (voir « Limites connues »).
- Chronomètre du téléphone de l'observateur, arrondi à la seconde.

## Après chaque test

1. Demander au testeur ce qui l'a gêné, en une phrase, et le noter.
2. Lui faire **annuler** sa réservation depuis « Mes réservations » (lien sur
   l'accueil), pour libérer le créneau. Ce n'est pas chronométré, mais noter
   s'il y arrive sans aide : c'est une vérification utile de #7.

## Résultats

Seuil : **moins de 2:00, sans aide**, pour chaque testeur.

| Testeur | Date | Téléphone / navigateur | Réseau | Temps (min:s) | Aide ? | E-mail du code > 30 s ? | Réussi ? | Ce qui a gêné | Annulation sans aide ? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sparta |  |  |  |  |  |  |  |  |  |
| T1 |  |  |  |  |  |  |  |  |  |
| T2 |  |  |  |  |  |  |  |  |  |
| T3 |  |  |  |  |  |  |  |  |  |
| T4 |  |  |  |  |  |  |  |  |  |
| T5 |  |  |  |  |  |  |  |  |  |

Sparta connaît le site : son temps sert de référence, il ne compte pas parmi
les 5 nouveaux clients.

**Synthèse** (à remplir après chaque série) :

- nombre de réussites sur le nombre de testeurs ;
- temps médian et temps le plus long ;
- blocages répétés : écran concerné et cause supposée.

Tout blocage répété devient une issue, avec l'écran concerné et les
observations.

## Limites connues

- **E-mail du code** : envoyé par le SMTP de Gmail (`docs/connexion-code-email.md`).
  Un délai de réception ou un passage en spam fausse le temps. On note ces
  cas à part, sans corriger le temps mesuré.
- **Données de démo** : les créneaux proviennent du script de démo
  (`docs/donnees-demo.md`). Si un créneau a été pris par un test précédent,
  il n'est plus proposé : c'est le comportement attendu.
- Le temps mesuré par les tests automatisés (Playwright, environ 1,5 s) n'est
  qu'indicatif : il ne remplace pas ce test.
