// Issue #148 : tests de la fonction inviter-coiffeur, réseau simulé.
// Lancer : deno test supabase/functions/inviter-coiffeur
import assert from "node:assert/strict";
import { type Config, traiter } from "./logique.ts";

type Appel = { url: string; init: RequestInit };

// Réponses prévues par chemin (sans l'hôte) ; chaque appel est noté.
function reseau(reponses: Record<string, () => Response>) {
  const appels: Appel[] = [];
  const faux = (async (entree: string | URL | Request, init?: RequestInit) => {
    const url = String(entree);
    appels.push({ url, init: init ?? {} });
    const chemin = url.replace("http://api.test", "").split("?")[0];
    const reponse = reponses[chemin];
    if (!reponse) throw new Error(`Pas de réponse prévue : ${chemin}`);
    return reponse();
  }) as typeof fetch;
  return { appels, faux };
}

const jsonRep = (corps: unknown, statut = 200) =>
  () => new Response(JSON.stringify(corps), { status: statut });

function config(faux: typeof fetch, cleSecrete = "service-role-jwt"): Config {
  return { url: "http://api.test", cleSecrete, fetch: faux };
}

function requete(corps: unknown, enTetes: Record<string, string> = {}) {
  return new Request("http://fonction.test", {
    method: "POST",
    headers: { Authorization: "Bearer jeton-gerant", apikey: "cle-publique", ...enTetes },
    body: typeof corps === "string" ? corps : JSON.stringify(corps),
  });
}

const saisie = { salon: "s1", email: "  Nour@Mail.TEST ", nom: " Nour   Ben " };

Deno.test("sans connexion : refus, aucun appel", async () => {
  const { appels, faux } = reseau({});
  const reponse = await traiter(
    new Request("http://fonction.test", { method: "POST", body: "{}" }),
    config(faux),
  );
  assert.equal(reponse.status, 401);
  assert.equal((await reponse.json()).code, "PT401");
  assert.equal(appels.length, 0);
});

Deno.test("requête mal formée : PT400, aucun appel", async () => {
  const { appels, faux } = reseau({});
  const reponse = await traiter(requete("pas du json"), config(faux));
  assert.equal(reponse.status, 400);
  assert.equal((await reponse.json()).code, "PT400");
  const incomplet = await traiter(requete({ salon: "s1" }), config(faux));
  assert.equal(incomplet.status, 400);
  assert.equal(appels.length, 0);
});

Deno.test("préflight CORS (app sur Chrome)", async () => {
  const { faux } = reseau({});
  const reponse = await traiter(
    new Request("http://fonction.test", { method: "OPTIONS" }),
    config(faux),
  );
  assert.equal(reponse.status, 200);
  assert.match(reponse.headers.get("Access-Control-Allow-Headers")!, /authorization/);
});

Deno.test("refus de la base (pas gérant) : renvoyé tel quel, pas d'e-mail", async () => {
  const { appels, faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep(
      { code: "PT403", message: "Invitation réservée au gérant du salon" },
      400,
    ),
  });
  const reponse = await traiter(requete(saisie), config(faux));
  assert.equal(reponse.status, 400);
  assert.deepEqual(await reponse.json(), {
    code: "PT403",
    message: "Invitation réservée au gérant du salon",
  });
  assert.equal(appels.length, 1);
});

Deno.test("la base est appelée avec le jeton du gérant, jamais la clé secrète", async () => {
  const { appels, faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep([{ resultat: "ajoute" }]),
  });
  await traiter(requete(saisie), config(faux));
  const enTetes = appels[0].init.headers as Record<string, string>;
  assert.equal(enTetes.Authorization, "Bearer jeton-gerant");
  assert.equal(enTetes.apikey, "cle-publique");
  assert.deepEqual(JSON.parse(String(appels[0].init.body)), {
    p_salon: "s1",
    p_email: saisie.email,
    p_nom: saisie.nom,
  });
});

Deno.test("compte confirmé existant : ajouté, pas d'e-mail d'invitation", async () => {
  const { appels, faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep([{ resultat: "ajoute" }]),
  });
  const reponse = await traiter(requete(saisie), config(faux));
  assert.deepEqual(await reponse.json(), { resultat: "ajoute" });
  assert.ok(!appels.some((a) => a.url.includes("/auth/v1/invite")));
});

Deno.test("invitation : e-mail envoyé avec la clé secrète, adresse et nom nettoyés", async () => {
  const { appels, faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep([{ resultat: "invite" }]),
    "/rest/v1/salons": jsonRep([{ nom: "Salon Sparta" }]),
    "/auth/v1/invite": jsonRep({ id: "u1" }),
  });
  const reponse = await traiter(requete(saisie), config(faux));
  assert.deepEqual(await reponse.json(), { resultat: "invite", emailEnvoye: true });

  const invite = appels.find((a) => a.url.endsWith("/auth/v1/invite"))!;
  const enTetes = invite.init.headers as Record<string, string>;
  assert.equal(enTetes.apikey, "service-role-jwt");
  assert.equal(enTetes.Authorization, "Bearer service-role-jwt");
  assert.deepEqual(JSON.parse(String(invite.init.body)), {
    email: "nour@mail.test",
    data: { nom: "Nour Ben", salon: "Salon Sparta" },
  });
});

Deno.test("nouvelle clé secrète (sb_secret_…) : seulement dans apikey", async () => {
  const { appels, faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep([{ resultat: "invite" }]),
    "/rest/v1/salons": jsonRep([{ nom: "Salon" }]),
    "/auth/v1/invite": jsonRep({ id: "u1" }),
  });
  await traiter(requete(saisie), config(faux, "sb_secret_abc"));
  const invite = appels.find((a) => a.url.endsWith("/auth/v1/invite"))!;
  const enTetes = invite.init.headers as Record<string, string>;
  assert.equal(enTetes.apikey, "sb_secret_abc");
  assert.equal(enTetes.Authorization, undefined);
});

Deno.test("e-mail refusé (limite d'envoi) : invitation gardée, raison donnée", async () => {
  const { faux } = reseau({
    "/rest/v1/rpc/inviter_coiffeur": jsonRep([{ resultat: "invite" }]),
    "/rest/v1/salons": jsonRep([]),
    "/auth/v1/invite": jsonRep(
      { error_code: "over_email_send_rate_limit", msg: "limite" },
      429,
    ),
  });
  const reponse = await traiter(requete(saisie), config(faux));
  assert.equal(reponse.status, 200);
  assert.deepEqual(await reponse.json(), {
    resultat: "invite",
    emailEnvoye: false,
    raison: "over_email_send_rate_limit",
  });
});
