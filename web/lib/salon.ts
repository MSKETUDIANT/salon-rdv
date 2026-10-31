import { cacheLife } from "next/cache";
import { createPublicClient } from "@/lib/supabase/public";

// Nom et adresse postale du salon (#129, null si absente), adresse publique
// de sa photo (#117, envoyée par le gérant dans l'app pro, #105 ; null : photo
// par défaut du site) et délai minimum d'annulation en minutes (#118, 0 :
// jusqu'au début du rendez-vous). Mis en cache :
// revalidé toutes les minutes (profil « minutes »), ce qui garde la page
// d'accueil statique.
export async function lireSalon(
  salonId: string,
): Promise<{
  nom: string;
  adresse: string | null;
  photo: string | null;
  delaiAnnulation: number;
} | null> {
  "use cache";
  cacheLife("minutes");

  const supabase = createPublicClient();
  const { data, error } = await supabase
    .from("salons")
    .select("nom, adresse, photo, delai_annulation_minutes")
    .eq("id", salonId)
    .maybeSingle();

  if (error) {
    throw new Error(`Lecture du salon impossible : ${error.message}`);
  }
  if (!data) return null;
  return {
    nom: data.nom,
    adresse: data.adresse,
    photo: data.photo
      ? supabase.storage.from("salons").getPublicUrl(data.photo).data.publicUrl
      : null,
    delaiAnnulation: data.delai_annulation_minutes,
  };
}
