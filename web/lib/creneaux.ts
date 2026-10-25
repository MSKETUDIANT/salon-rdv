import type { Database } from "@/lib/database.types";
import { env } from "@/lib/env";

// Créneaux renvoyés par la fonction SQL creneaux_disponibles (#5).
export type Creneau = Database["public"]["Functions"]["creneaux_disponibles"]["Returns"][number];

export type Jour = {
  cle: string; // AAAA-MM-JJ, date locale du salon
  libelle: string; // « Lundi 27 octobre »
  court: string; // « lun. »
  numero: string; // « 27 »
  heures: { debut: string; libelle: string }[]; // vide : aucun créneau ce jour
};

// Fenêtre affichée : aujourd'hui et les 13 jours suivants.
export const JOURS_AFFICHES = 14;

// Date locale (AAAA-MM-JJ) d'un instant dans le fuseau du salon.
export function jourLocal(instant: Date, fuseau: string): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: fuseau,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(instant);
}

export function ajouterJours(jour: string, n: number): string {
  const date = new Date(`${jour}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + n);
  return date.toISOString().slice(0, 10);
}

// Période demandée à la base, en dates locales du salon.
export function periode(maintenant: Date, fuseau: string): { du: string; au: string } {
  const du = jourLocal(maintenant, fuseau);
  return { du, au: ajouterJours(du, JOURS_AFFICHES - 1) };
}

// Lit les créneaux via /api/creneaux (réécrit vers PostgREST, next.config.ts),
// sans supabase-js : moins de JavaScript à charger en 3G (BNF-5).
export async function lireCreneaux(
  demande: { prestationId: string; du: string; au: string; coiffeurId?: string },
  signal?: AbortSignal,
): Promise<Creneau[]> {
  const params = new URLSearchParams({
    p_prestation: demande.prestationId,
    p_du: demande.du,
    p_au: demande.au,
  });
  if (demande.coiffeurId) params.set("p_coiffeur", demande.coiffeurId);

  const reponse = await fetch(`/api/creneaux?${params}`, {
    headers: { apikey: env.supabaseAnonKey },
    signal,
  });
  if (!reponse.ok) {
    throw new Error(`Lecture des créneaux impossible (HTTP ${reponse.status})`);
  }
  return reponse.json();
}

// Les jours de la période (à partir de `du`), chacun avec ses créneaux. Une
// même heure proposée par plusieurs coiffeurs (« Peu importe ») n'apparaît
// qu'une fois.
export function grouperParJour(
  creneaux: Creneau[],
  fuseau: string,
  du: string,
  nombreJours = JOURS_AFFICHES,
): Jour[] {
  // Les libellés d'un jour ne dépendent que de sa date : midi UTC, lu en UTC.
  const libelleJour = (cle: string, options: Intl.DateTimeFormatOptions) =>
    new Intl.DateTimeFormat("fr-FR", { timeZone: "UTC", ...options }).format(
      new Date(`${cle}T12:00:00Z`),
    );
  const formatHeure = new Intl.DateTimeFormat("fr-FR", {
    timeZone: fuseau,
    hour: "2-digit",
    minute: "2-digit",
  });

  const jours = Array.from({ length: nombreJours }, (_, i): Jour => {
    const cle = ajouterJours(du, i);
    const libelle = libelleJour(cle, { weekday: "long", day: "numeric", month: "long" });
    return {
      cle,
      libelle: libelle.charAt(0).toUpperCase() + libelle.slice(1),
      court: libelleJour(cle, { weekday: "short" }),
      numero: libelleJour(cle, { day: "numeric" }),
      heures: [],
    };
  });
  const parCle = new Map(jours.map((jour) => [jour.cle, jour]));

  const vus = new Set<number>();
  const tries = [...creneaux].sort((a, b) => Date.parse(a.debut) - Date.parse(b.debut));
  for (const { debut } of tries) {
    const instant = new Date(debut);
    if (vus.has(instant.getTime())) continue;
    vus.add(instant.getTime());
    parCle
      .get(jourLocal(instant, fuseau))
      ?.heures.push({ debut: instant.toISOString(), libelle: formatHeure.format(instant) });
  }

  return jours;
}

// Lien vers l'écran 3 (confirmation, #6). Sans coiffeur : « Peu importe ».
export function lienConfirmation(prestationId: string, debut: string, coiffeurId?: string): string {
  const params = new URLSearchParams({ prestation: prestationId, debut });
  if (coiffeurId) params.set("coiffeur", coiffeurId);
  return `/reserver/confirmation?${params}`;
}

// Mois de la bande de jours (#55) : « Octobre 2026 », « Octobre – novembre
// 2026 », ou « Décembre 2026 – janvier 2027 » à cheval sur deux années.
export function moisDeLaBande(jours: Jour[]): string {
  if (jours.length === 0) return "";
  const nom = (cle: string, options: Intl.DateTimeFormatOptions) =>
    new Intl.DateTimeFormat("fr-FR", { timeZone: "UTC", ...options }).format(
      new Date(`${cle}T12:00:00Z`),
    );
  const premier = jours[0].cle;
  const dernier = jours[jours.length - 1].cle;
  const capitale = (texte: string) => texte.charAt(0).toUpperCase() + texte.slice(1);
  if (premier.slice(0, 7) === dernier.slice(0, 7)) {
    return capitale(nom(premier, { month: "long", year: "numeric" }));
  }
  if (premier.slice(0, 4) === dernier.slice(0, 4)) {
    return `${capitale(nom(premier, { month: "long" }))} – ${nom(dernier, { month: "long", year: "numeric" })}`;
  }
  return `${capitale(nom(premier, { month: "long", year: "numeric" }))} – ${nom(dernier, { month: "long", year: "numeric" })}`;
}

// Repère « nov. » devant le premier jour d'un nouveau mois dans la bande
// (#55) ; null pour les autres jours et pour le premier jour de la bande.
export function repereMois(jours: Jour[], index: number): string | null {
  if (index === 0 || !jours[index].cle.endsWith("-01")) return null;
  return new Intl.DateTimeFormat("fr-FR", { timeZone: "UTC", month: "short" }).format(
    new Date(`${jours[index].cle}T12:00:00Z`),
  );
}
