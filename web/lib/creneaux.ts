import type { Database } from "@/lib/database.types";
import { env } from "@/lib/env";

// Créneaux renvoyés par la fonction SQL creneaux_disponibles (#5).
export type Creneau = Database["public"]["Functions"]["creneaux_disponibles"]["Returns"][number];

export type Jour = {
  cle: string; // AAAA-MM-JJ, date locale du salon
  libelle: string; // « Lundi 27 octobre »
  heures: { debut: string; libelle: string }[];
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

// Regroupe les créneaux par jour local. Une même heure proposée par plusieurs
// coiffeurs (« Peu importe ») n'apparaît qu'une fois.
export function grouperParJour(creneaux: Creneau[], fuseau: string): Jour[] {
  const formatJour = new Intl.DateTimeFormat("fr-FR", {
    timeZone: fuseau,
    weekday: "long",
    day: "numeric",
    month: "long",
  });
  const formatHeure = new Intl.DateTimeFormat("fr-FR", {
    timeZone: fuseau,
    hour: "2-digit",
    minute: "2-digit",
  });

  const jours = new Map<string, Jour>();
  const vus = new Set<number>();
  const tries = [...creneaux].sort((a, b) => Date.parse(a.debut) - Date.parse(b.debut));

  for (const { debut } of tries) {
    const instant = new Date(debut);
    if (vus.has(instant.getTime())) continue;
    vus.add(instant.getTime());

    const cle = jourLocal(instant, fuseau);
    let jour = jours.get(cle);
    if (!jour) {
      const libelle = formatJour.format(instant);
      jour = { cle, libelle: libelle.charAt(0).toUpperCase() + libelle.slice(1), heures: [] };
      jours.set(cle, jour);
    }
    jour.heures.push({ debut: instant.toISOString(), libelle: formatHeure.format(instant) });
  }

  return [...jours.values()];
}

// Lien vers l'écran 3 (confirmation, #6). Sans coiffeur : « Peu importe ».
export function lienConfirmation(prestationId: string, debut: string, coiffeurId?: string): string {
  const params = new URLSearchParams({ prestation: prestationId, debut });
  if (coiffeurId) params.set("coiffeur", coiffeurId);
  return `/reserver/confirmation?${params}`;
}
