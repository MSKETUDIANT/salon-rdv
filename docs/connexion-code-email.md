# Connexion par code e-mail (base distante)

Le client se connecte à l'écran de confirmation avec un **code à 6 chiffres**
reçu par e-mail (charte graphique §5, issue #6). Pas de mot de passe, pas de
lien magique. Le gérant et l'app pro gardent l'e-mail et le mot de passe ; en
cas d'oubli, l'app pro envoie aussi un **code à 6 chiffres** pour choisir un
nouveau mot de passe (issue #39), jamais de lien.

> En local, rien à faire : `supabase/config.toml` règle la longueur du code
> (`otp_length = 6`) et les trois modèles d'e-mail
> (`supabase/templates/code-connexion.html`,
> `supabase/templates/code-reinitialisation.html`) ; les e-mails arrivent dans
> Mailpit.

Ces réglages ne passent pas par une migration : ils se font dans le dashboard
Supabase. Ne pas utiliser `supabase config push` : il pousserait tout
`config.toml`, y compris `site_url` et les autres réglages locaux.

## Procédure (une fois, avec l'accord de Sparta)

Faite par Sparta en distant le 2026-10-25, dans l'ordre ci-dessous.

### 1. Site URL

*Authentication → URL Configuration* : **Site URL** =
`https://salon-rdv-one.vercel.app` (elle valait `http://localhost:3000`, la
valeur par défaut). Le code n'utilise pas de lien, mais Supabase se sert de
cette adresse comme adresse par défaut dans ses e-mails et ses redirections.

### 2. Serveur SMTP externe

Le dashboard ne permet de modifier les modèles d'e-mail qu'avec un SMTP
externe : cette étape vient donc avant les modèles.

*Authentication → Emails → SMTP Settings* : activer **Enable Custom SMTP**,
avec le SMTP de Gmail :

- **Host** : `smtp.gmail.com`, **Port** : `465` (ou `587`) ;
- **Username** : l'adresse Gmail d'envoi ;
- **Password** : un **mot de passe d'application** Google (compte Google →
  Sécurité → Validation en deux étapes → Mots de passe des applications),
  jamais le mot de passe du compte ;
- **Sender email** : la même adresse Gmail ; **Sender name** : le nom du salon.

Le mot de passe d'application ne vit que dans le dashboard : jamais dans le
dépôt ni dans `.env.local`. Pour le révoquer : compte Google → Mots de passe
des applications.

### 3. Longueur du code

*Authentication → Sign In / Providers → Email* :

- **Email OTP Length** : `6` ;
- **Email OTP Expiration** : `3600` secondes (comme en local) ;
- le fournisseur Email reste activé (le gérant s'en sert aussi).

### 4. Modèles d'e-mail

*Authentication → Emails → Templates*. Supabase envoie le modèle
**Magic Link** à un compte existant et **Confirm signup** à un nouveau compte :
les deux doivent contenir le code, et aucun lien.

Pour **chacun** des deux modèles :

- **Subject** : `Votre code de connexion` ;
- **Body** : le contenu de `supabase/templates/code-connexion.html`, tel quel
  (il affiche `{{ .Token }}`, le code).

Ces deux modèles servent aussi à l'app pro (#148) : « Pas encore de mot de
passe, ou oublié ? » envoie ce même code au coiffeur invité (premier mot de
passe) comme au compte qui a oublié le sien. Leur texte dit « sur le site du
salon ou dans l'app pro ». Après une modification de `code-connexion.html`,
recoller le Body dans les deux modèles du dashboard (fait par Sparta).

Invitation d'un coiffeur (#148, fait par Sparta avant la mise en ligne) :
modèle **Invite user** :

- **Subject** : `Invitation à rejoindre l'équipe du salon` ;
- **Body** : le contenu de `supabase/templates/invitation-coiffeur.html`, tel
  quel (lien de l'app pro, marche à suivre ; aucun lien de connexion ni code :
  le code est demandé dans l'app).

Le modèle **Reset Password** (#39) n'est plus utilisé par l'app depuis #148 ;
il peut rester tel quel.

### 5. Vérifier

1. Sur le site déployé, aller jusqu'à l'écran de confirmation, saisir un nom et
   une adresse e-mail, puis « Recevoir le code ».
2. L'e-mail reçu a pour objet « Votre code de connexion », contient 6 chiffres
   et aucun lien.
3. Saisir le code : « Connecté avec … » s'affiche.
4. Refaire le test avec une adresse **jamais utilisée** (navigation privée) :
   c'est le modèle « Confirm signup » qui part, il doit aussi contenir le code.
5. Dans l'app pro, « Pas encore de mot de passe, ou oublié ? » avec l'adresse
   d'un compte de l'équipe : l'e-mail « Votre code de connexion » contient
   6 chiffres ; le code permet de choisir un nouveau mot de passe.
6. Dans l'app pro, le gérant invite une adresse de test (Salon → Équipe →
   « Ajouter un coiffeur ») : l'e-mail « Invitation à rejoindre l'équipe du
   salon » arrive, avec le lien de l'app ; puis, avec cette adresse,
   « Pas encore de mot de passe, ou oublié ? » : le code permet de choisir un
   mot de passe, et l'espace coiffeur s'ouvre.

## Limite d'envoi

Le SMTP intégré de Supabase n'envoie que quelques e-mails par heure : il a été
remplacé par Gmail (étape 2). Gmail suffit pour les tests et la démo, mais
plafonne autour de quelques centaines d'envois par jour, et les e-mails partent
d'une adresse personnelle. Avant la mise en service, passer à un service
d'envoi transactionnel avec le domaine du salon (`docs/dette-technique.md`,
#13).
