import { cacheLife } from "next/cache";
import { createPublicClient } from "@/lib/supabase/public";

// Nom du salon et adresse publique de sa photo (#117, envoyée par le gérant
// dans l'app pro, #105 ; null : photo par défaut du site). Mis en cache :
// revalidé toutes les minutes (profil « minutes »), ce qui garde la page
// d'accueil statique.
export async function lireSalon(
  salonId: string,
): Promise<{ nom: string; photo: string | null } | null> {
  "use cache";
  cacheLife("minutes");

  const supabase = createPublicClient();
  const { data, error } = await supabase
    .from("salons")
    .select("nom, photo")
    .eq("id", salonId)
    .maybeSingle();

  if (error) {
    throw new Error(`Lecture du salon impossible : ${error.message}`);
  }
  if (!data) return null;
  return {
    nom: data.nom,
    photo: data.photo
      ? supabase.storage.from("salons").getPublicUrl(data.photo).data.publicUrl
      : null,
  };
}
