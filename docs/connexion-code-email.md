# Connexion par code e-mail (base distante)

Le client se connecte à l'écran de confirmation avec un **code à 6 chiffres**
reçu par e-mail (charte graphique §5, issue #6). Pas de mot de passe, pas de
lien magique. Le gérant et l'app pro gardent l'e-mail et le mot de passe.

> En local, rien à faire : `supabase/config.toml` règle la longueur du code
> (`otp_length = 6`) et les deux modèles d'e-mail
> (`supabase/templates/code-connexion.html`) ; les e-mails arrivent dans
> Mailpit.

Ces réglages ne passent pas par une migration : ils se font dans le dashboard
Supabase. Ne pas utiliser `supabase config push` : il pousserait tout
`config.toml`, y compris `site_url` et les autres réglages locaux.

## Procédure (une fois, avec l'accord de Sparta)

### 1. Longueur du code

*Authentication → Sign In / Providers → Email* :

- **Email OTP Length** : `6` ;
- **Email OTP Expiration** : `3600` secondes (comme en local) ;
- le fournisseur Email reste activé (le gérant s'en sert aussi).

### 2. Modèles d'e-mail

*Authentication → Emails → Templates*. Supabase envoie le modèle
**Magic Link** à un compte existant et **Confirm signup** à un nouveau compte :
les deux doivent contenir le code, et aucun lien.

Pour **chacun** des deux modèles :

- **Subject** : `Votre code de connexion` ;
- **Body** : le contenu de `supabase/templates/code-connexion.html`, tel quel
  (il affiche `{{ .Token }}`, le code).

### 3. Vérifier

1. Sur le site déployé, aller jusqu'à l'écran de confirmation, saisir un nom et
   une adresse e-mail, puis « Recevoir le code ».
2. L'e-mail reçu a pour objet « Votre code de connexion », contient 6 chiffres
   et aucun lien.
3. Saisir le code : « Connecté avec … » s'affiche.

## Limite d'envoi

Sans serveur SMTP externe, Supabase n'envoie que peu d'e-mails par heure (et,
selon sa documentation, seulement à certaines adresses autorisées, comme celles
des membres de l'organisation : à vérifier dans le dashboard, *Authentication →
Emails → SMTP Settings*). Suffisant pour vérifier le parcours, pas pour de
vrais clients : SMTP externe obligatoire avant la mise en service
(`docs/dette-technique.md`, #13).
