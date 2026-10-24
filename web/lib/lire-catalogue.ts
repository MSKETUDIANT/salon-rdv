import { cacheLife } from "next/cache";
import type { Catalogue } from "@/lib/catalogue";
import { createPublicClient } from "@/lib/supabase/public";

// Catalogue public du salon : prestations actives, coiffeurs et leurs
// compétences, fuseau horaire. Mis en cache (revalidé toutes les minutes) : les
// écrans 1 et 2 du parcours restent statiques, seuls les créneaux sont lus au
// chargement.
export async function lireCatalogue(salonId: string): Promise<Catalogue> {
  "use cache";
  cacheLife("minutes");

  const supabase = createPublicClient();
  const [salon, prestations, coiffeurs, competences] = await Promise.all([
    supabase.from("salons").select("fuseau_horaire").eq("id", salonId).single(),
    supabase
      .from("prestations")
      .select("id, nom, prix, duree_minutes")
      .eq("salon_id", salonId)
      .eq("active", true)
      .order("nom"),
    supabase.rpc("coiffeurs_du_salon", { p_salon: salonId }),
    supabase.from("competences").select("coiffeur_id, prestation_id"),
  ]);

  for (const { error } of [salon, prestations, coiffeurs, competences]) {
    if (error) {
      throw new Error(`Lecture du catalogue impossible : ${error.message}`);
    }
  }

  return {
    fuseau: salon.data!.fuseau_horaire,
    prestations: prestations.data!.map((p) => ({
      id: p.id,
      nom: p.nom,
      prix: p.prix,
      dureeMinutes: p.duree_minutes,
    })),
    coiffeurs: coiffeurs.data!.map((c) => ({
      id: c.id,
      nom: c.nom,
      prestations: competences
        .data!.filter((k) => k.coiffeur_id === c.id)
        .map((k) => k.prestation_id),
    })),
  };
}
