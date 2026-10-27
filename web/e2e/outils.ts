import { expect, type Page } from "@playwright/test";

// Outils des tests de bout en bout (base locale, voir playwright.config.ts).

const api = () => process.env.E2E_API_URL!;
const mailpit = () => process.env.E2E_MAILPIT_URL!;

// Données du seed (supabase/seed.sql).
export const SEED = {
  coupeHomme: "66666666-0000-0000-0000-000000000002",
  amira: "44444444-4444-4444-4444-444444444444",
};

export function emailUnique(prefixe: string): string {
  return `${prefixe}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@e2e.test`;
}

// Attente entre deux codes pour un même e-mail : max_frequency de
// [auth.email] (1 s, supabase/config.toml), plus 200 ms de marge. Plus tôt,
// l'Auth répond 429 et le site affiche « Trop de demandes » (#59).
const DELAI_ENTRE_CODES = 1_200;
const codeRecuA = new Map<string, number>();

// Attend que l'Auth accepte un nouveau code pour cet e-mail.
export async function attendreDelaiEntreCodes(email: string) {
  const reste = (codeRecuA.get(email) ?? 0) + DELAI_ENTRE_CODES - Date.now();
  if (reste > 0) await new Promise((fin) => setTimeout(fin, reste));
}

// Code à 6 chiffres du dernier e-mail reçu par cette adresse (Mailpit).
// precedent : code déjà reçu, à ignorer (attendre le nouvel e-mail).
export async function lireCode(email: string, precedent?: string): Promise<string> {
  for (let essai = 0; essai < 20; essai++) {
    const recherche = await fetch(
      `${mailpit()}/api/v1/search?query=${encodeURIComponent(`to:"${email}"`)}`,
    ).then((r) => r.json());
    const dernier = recherche.messages?.[0];
    if (dernier) {
      const message = await fetch(`${mailpit()}/api/v1/message/${dernier.ID}`).then((r) => r.json());
      const code = String(message.Text).match(/\b\d{6}\b/)?.[0];
      if (code && code !== precedent) {
        codeRecuA.set(email, Date.now());
        return code;
      }
    }
    await new Promise((fin) => setTimeout(fin, 500));
  }
  throw new Error(`Aucun code reçu pour ${email}`);
}

// Connexion par code e-mail, sur l'écran 3, sans le quitter.
export async function seConnecter(page: Page, nom: string, email: string) {
  await page.getByLabel("Nom").fill(nom);
  await page.getByLabel("E-mail").fill(email);
  await page.getByRole("button", { name: "Recevoir le code" }).click();
  await page.getByLabel("Code à 6 chiffres").fill(await lireCode(email));
  await page.getByRole("button", { name: "Valider le code" }).click();
  await expect(page.getByText("Connecté avec")).toBeVisible();
}

// Un créneau libre (fonction SQL creneaux_disponibles, clé anon).
export async function creneauLibre(prestation: string, coiffeur?: string): Promise<string> {
  const du = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Tunis" }).format(new Date());
  const fin = new Date(`${du}T00:00:00Z`);
  fin.setUTCDate(fin.getUTCDate() + 13);
  const reponse = await fetch(`${api()}/rest/v1/rpc/creneaux_disponibles`, {
    method: "POST",
    headers: { apikey: process.env.E2E_ANON_KEY!, "Content-Type": "application/json" },
    body: JSON.stringify({
      p_prestation: prestation,
      p_du: du,
      p_au: fin.toISOString().slice(0, 10),
      p_coiffeur: coiffeur ?? null,
    }),
  });
  const creneaux: { debut: string }[] = await reponse.json();
  if (!creneaux.length) throw new Error("Aucun créneau libre dans le seed");
  return new Date(creneaux[Math.min(3, creneaux.length - 1)].debut).toISOString();
}

// Réservations non annulées d'un créneau, avec l'e-mail du client (clé
// service : lecture hors RLS, base locale uniquement).
export async function reservationsA(
  debut: string,
): Promise<{ coiffeur_id: string; statut: string; client: { email: string } }[]> {
  const params = new URLSearchParams({
    select: "coiffeur_id,statut,client:utilisateurs!reservations_client_id_fkey(email)",
    debut: `eq.${debut}`,
    statut: "neq.annulee",
  });
  const cle = process.env.E2E_SERVICE_ROLE_KEY!;
  const reponse = await fetch(`${api()}/rest/v1/reservations?${params}`, {
    headers: { apikey: cle, Authorization: `Bearer ${cle}` },
  });
  return reponse.json();
}

// Statuts des réservations d'un client sur un créneau, annulées comprises
// (clé service, base locale uniquement).
export async function statutsDuClient(debut: string, email: string): Promise<string[]> {
  const params = new URLSearchParams({
    select: "statut,client:utilisateurs!reservations_client_id_fkey!inner(email)",
    debut: `eq.${debut}`,
    "client.email": `eq.${email}`,
  });
  const cle = process.env.E2E_SERVICE_ROLE_KEY!;
  const reponse = await fetch(`${api()}/rest/v1/reservations?${params}`, {
    headers: { apikey: cle, Authorization: `Bearer ${cle}` },
  });
  return ((await reponse.json()) as { statut: string }[]).map((r) => r.statut);
}

// Le créneau est-il proposé (fonction SQL creneaux_disponibles, clé anon) ?
export async function creneauPropose(prestation: string, coiffeur: string, debut: string) {
  const jour = new Intl.DateTimeFormat("en-CA", { timeZone: "Africa/Tunis" }).format(new Date(debut));
  const reponse = await fetch(`${api()}/rest/v1/rpc/creneaux_disponibles`, {
    method: "POST",
    headers: { apikey: process.env.E2E_ANON_KEY!, "Content-Type": "application/json" },
    body: JSON.stringify({ p_prestation: prestation, p_du: jour, p_au: jour, p_coiffeur: coiffeur }),
  });
  const creneaux: { debut: string }[] = await reponse.json();
  return creneaux.some((c) => new Date(c.debut).getTime() === new Date(debut).getTime());
}

// Jeton d'un client par l'API Auth, sans navigateur : code demandé, lu dans
// Mailpit, puis vérifié. Crée le compte s'il n'existe pas.
export async function jetonClient(email: string, nom: string): Promise<string> {
  const entetes = { apikey: process.env.E2E_ANON_KEY!, "Content-Type": "application/json" };
  const otp = await fetch(`${api()}/auth/v1/otp`, {
    method: "POST",
    headers: entetes,
    body: JSON.stringify({ email, create_user: true, data: { nom } }),
  });
  if (!otp.ok) throw new Error(`Envoi du code impossible : ${otp.status}`);
  const verification = await fetch(`${api()}/auth/v1/verify`, {
    method: "POST",
    headers: entetes,
    body: JSON.stringify({ type: "email", email, token: await lireCode(email) }),
  });
  const { access_token } = await verification.json();
  if (!access_token) throw new Error(`Code refusé pour ${email}`);
  return access_token;
}

// Appel de l'API REST de la base au nom d'un client (son jeton) ; sans jeton,
// en visiteur (clé anon).
export function apiClient(jeton: string | null, chemin: string, init: RequestInit = {}) {
  return fetch(`${api()}/rest/v1/${chemin}`, {
    ...init,
    headers: {
      apikey: process.env.E2E_ANON_KEY!,
      ...(jeton ? { Authorization: `Bearer ${jeton}` } : {}),
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
}
