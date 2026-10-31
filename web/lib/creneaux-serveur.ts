import type { Creneau } from "@/lib/creneaux";
import { createPublicClient } from "@/lib/supabase/public";

// Lecture des créneaux côté serveur (#46, option A de Sparta) : la liste de
// l'écran 2 part dans le HTML, sans attendre le JavaScript de la page (BNF-5).
// Même fonction SQL que lireCreneaux() côté navigateur, jamais mise en cache :
// les créneaux doivent être à jour à chaque visite.
export async function lireCreneauxServeur(demande: {
  prestationId: string;
  du: string;
  au: string;
  coiffeurId?: string;
}): Promise<Creneau[]> {
  const { data, error } = await createPublicClient().rpc("creneaux_disponibles", {
    p_prestation: demande.prestationId,
    p_du: demande.du,
    p_au: demande.au,
    ...(demande.coiffeurId ? { p_coiffeur: demande.coiffeurId } : {}),
  });
  if (error) {
    throw new Error(`Lecture des créneaux impossible : ${error.message}`);
  }
  return data;
}
