// Issue #148 : le gérant invite un coiffeur depuis l'app pro, et l'e-mail
// d'invitation part tout de suite.
//   1. inviter_coiffeur() est appelée avec le jeton du gérant : la base vérifie
//      la connexion, le rôle de gérant et la saisie (PT401, PT403, PT400,
//      PT409), et ses erreurs reviennent telles quelles à l'app ;
//   2. 'ajoute' (compte confirmé existant) : rien à envoyer ;
//   3. 'invite' : Supabase Auth crée le compte (adresse non confirmée) et
//      envoie le modèle « Invite user ». Seule cette étape utilise la clé
//      secrète, qui reste sur les serveurs de Supabase.
// Sans dépendance : appels HTTP directs à PostgREST et à l'API Auth.

export type Config = {
  url: string;
  // Clé secrète (service_role, ou sb_secret_… des nouvelles clés).
  cleSecrete: string;
  fetch: typeof fetch;
};

const enTetesCors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(corps: unknown, statut = 200): Response {
  return new Response(JSON.stringify(corps), {
    status: statut,
    headers: { ...enTetesCors, "Content-Type": "application/json" },
  });
}

function refus(code: string, message: string, statut: number): Response {
  return json({ code, message }, statut);
}

// Une nouvelle clé (sb_secret_…) n'est pas un jeton : elle va seulement dans
// apikey. L'ancienne (service_role) va aussi dans Authorization.
function enTetesSecrets(cle: string): Record<string, string> {
  return cle.startsWith("sb_")
    ? { apikey: cle }
    : { apikey: cle, Authorization: `Bearer ${cle}` };
}

export async function traiter(requete: Request, config: Config): Promise<Response> {
  if (requete.method === "OPTIONS") {
    return new Response("ok", { headers: enTetesCors });
  }
  if (requete.method !== "POST") {
    return refus("PT405", "Méthode non permise", 405);
  }

  const jeton = requete.headers.get("Authorization");
  const apikey = requete.headers.get("apikey");
  if (!jeton || !apikey) {
    return refus("PT401", "Connexion requise", 401);
  }

  let salon: unknown, email: unknown, nom: unknown;
  try {
    ({ salon, email, nom } = await requete.json());
  } catch {
    return refus("PT400", "Requête invalide", 400);
  }
  if (typeof salon !== "string" || typeof email !== "string" || typeof nom !== "string") {
    return refus("PT400", "Requête invalide", 400);
  }

  // Même jeton et même clé que l'app : la base voit le gérant connecté.
  const enTetesGerant = {
    apikey,
    Authorization: jeton,
    "Content-Type": "application/json",
  };
  const appel = await config.fetch(`${config.url}/rest/v1/rpc/inviter_coiffeur`, {
    method: "POST",
    headers: enTetesGerant,
    body: JSON.stringify({ p_salon: salon, p_email: email, p_nom: nom }),
  });
  if (!appel.ok) {
    // Erreur de la base (code et message de PostgREST) renvoyée telle quelle.
    return json(await appel.json().catch(() => ({})), appel.status);
  }
  const lignes = await appel.json();
  if (lignes?.[0]?.resultat === "ajoute") {
    return json({ resultat: "ajoute" });
  }

  // Nom du salon pour l'e-mail ; en cas d'échec, l'e-mail part sans.
  let nomSalon = "";
  try {
    const lecture = await config.fetch(
      `${config.url}/rest/v1/salons?id=eq.${encodeURIComponent(salon)}&select=nom`,
      { headers: enTetesGerant },
    );
    if (lecture.ok) nomSalon = (await lecture.json())?.[0]?.nom ?? "";
  } catch {
    // Sans nom de salon.
  }

  // Comme la base : e-mail en minuscules, espaces du nom réduits.
  const adresse = email.trim().toLowerCase();
  const nomPropre = nom.trim().replace(/\s+/g, " ");
  const envoi = await config.fetch(`${config.url}/auth/v1/invite`, {
    method: "POST",
    headers: { ...enTetesSecrets(config.cleSecrete), "Content-Type": "application/json" },
    body: JSON.stringify({ email: adresse, data: { nom: nomPropre, salon: nomSalon } }),
  });
  if (envoi.ok) {
    return json({ resultat: "invite", emailEnvoye: true });
  }
  // L'invitation reste enregistrée : le gérant pourra la renvoyer.
  const erreur = await envoi.json().catch(() => ({}));
  return json({
    resultat: "invite",
    emailEnvoye: false,
    raison: erreur?.error_code ?? erreur?.code ?? String(envoi.status),
  });
}
