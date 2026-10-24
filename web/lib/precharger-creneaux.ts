import type { Creneau } from "@/lib/creneaux";

// Appel anticipé des créneaux de l'écran 2 (BNF-5). Un <script> de la page
// statique lance la lecture dès la réception du HTML, sans attendre le
// JavaScript de la page ; l'écran reprend ensuite cette lecture au lieu d'en
// lancer une nouvelle. Ne couvre que le premier affichage (« Peu importe »).

const CLE = "__creneauxPrecharges";

type Prechargement = { prestation: string; du: string; au: string; promesse: Promise<Creneau[]> };

// Sérialisée dans le <script> : doit rester autonome (aucune référence à ce
// module ni import). Même période et même requête que periode() et
// lireCreneaux() de lib/creneaux.ts (vérifié par les tests).
export function prechargerCreneaux(fuseau: string, jours: number, apikey: string, cle: string) {
  try {
    const prestation = new URLSearchParams(location.search).get("prestation");
    if (!prestation) return;
    const du = new Intl.DateTimeFormat("en-CA", {
      timeZone: fuseau,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(new Date());
    const dernier = new Date(`${du}T00:00:00Z`);
    dernier.setUTCDate(dernier.getUTCDate() + jours - 1);
    const au = dernier.toISOString().slice(0, 10);

    const params = new URLSearchParams({ p_prestation: prestation, p_du: du, p_au: au });
    const promesse = fetch(`/api/creneaux?${params}`, { headers: { apikey } }).then((reponse) => {
      if (!reponse.ok) throw new Error(`Lecture des créneaux impossible (HTTP ${reponse.status})`);
      return reponse.json();
    });
    // Évite une erreur « non gérée » si l'écran ne reprend jamais la lecture.
    promesse.catch(() => {});
    (window as unknown as Record<string, unknown>)[cle] = { prestation, du, au, promesse };
  } catch {
    // En cas d'échec, l'écran lira les créneaux lui-même.
  }
}

// Contenu du <script> inclus dans la page de l'écran 2.
export function scriptPrechargement(fuseau: string, jours: number, apikey: string): string {
  const args = [JSON.stringify(fuseau), jours, JSON.stringify(apikey), JSON.stringify(CLE)];
  return `(${prechargerCreneaux.toString()})(${args.join(",")});`;
}

// Reprend la lecture anticipée si elle correspond à la demande (une seule fois).
export function prendrePrechargement(demande: {
  prestationId: string;
  du: string;
  au: string;
}): Promise<Creneau[]> | undefined {
  const global = window as unknown as Record<string, Prechargement | undefined>;
  const prechargement = global[CLE];
  delete global[CLE];
  if (
    prechargement?.prestation === demande.prestationId &&
    prechargement.du === demande.du &&
    prechargement.au === demande.au
  ) {
    return prechargement.promesse;
  }
  return undefined;
}
