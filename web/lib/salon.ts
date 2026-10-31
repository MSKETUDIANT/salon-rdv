import { cacheLife } from "next/cache";
import { createPublicClient } from "@/lib/supabase/public";

// Horaires d'ouverture d'un jour (1 = lundi ... 7 = dimanche), heures locales
// du salon « HH:MM » (issue 129, règle de horaires_du_salon()). Jour absent :
// fermé.
export type HoraireJour = { jour: number; ouverture: string; fermeture: string };

// Nom, adresse postale et téléphone du salon (#129, null si absents), horaires
// d'ouverture (#129), adresse publique de sa photo (#117, envoyée par le
// gérant dans l'app pro, #105 ; null : photo par défaut du site) et délai
// minimum d'annulation en minutes (#118, 0 : jusqu'au début du rendez-vous).
// Mis en cache : revalidé toutes les minutes (profil « minutes »), ce qui
// garde la page d'accueil statique.
export async function lireSalon(salonId: string): Promise<{
  nom: string;
  adresse: string | null;
  telephone: string | null;
  horaires: HoraireJour[];
  photo: string | null;
  delaiAnnulation: number;
} | null> {
  "use cache";
  cacheLife("minutes");

  const supabase = createPublicClient();
  const [salon, horaires] = await Promise.all([
    supabase
      .from("salons")
      .select("nom, adresse, telephone, photo, delai_annulation_minutes")
      .eq("id", salonId)
      .maybeSingle(),
    supabase.rpc("horaires_du_salon", { p_salon: salonId }),
  ]);

  for (const { error } of [salon, horaires]) {
    if (error) {
      throw new Error(`Lecture du salon impossible : ${error.message}`);
    }
  }
  const data = salon.data;
  if (!data) return null;
  return {
    nom: data.nom,
    adresse: data.adresse,
    telephone: data.telephone,
    horaires: horaires.data!.map((h) => ({
      jour: h.jour_semaine,
      ouverture: h.ouverture.slice(0, 5),
      fermeture: h.fermeture.slice(0, 5),
    })),
    photo: data.photo
      ? supabase.storage.from("salons").getPublicUrl(data.photo).data.publicUrl
      : null,
    delaiAnnulation: data.delai_annulation_minutes,
  };
}
