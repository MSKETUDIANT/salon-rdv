import { cacheLife } from "next/cache";
import { createPublicClient } from "@/lib/supabase/public";

// Nom du salon, mis en cache : revalidé toutes les minutes (profil « minutes »),
// ce qui garde la page d'accueil statique.
export async function lireSalon(salonId: string): Promise<{ nom: string } | null> {
  "use cache";
  cacheLife("minutes");

  const { data, error } = await createPublicClient()
    .from("salons")
    .select("nom")
    .eq("id", salonId)
    .maybeSingle();

  if (error) {
    throw new Error(`Lecture du salon impossible : ${error.message}`);
  }
  return data;
}
