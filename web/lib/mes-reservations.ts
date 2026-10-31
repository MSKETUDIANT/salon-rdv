import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";
import { formatDuree } from "@/lib/format";

// « Mes réservations » (#7, BF-C6) : fonctions SQL mes_reservations et
// annuler_reservation, qui ne portent que sur le client connecté (BNF-3).

type Client = SupabaseClient<Database>;
type Ligne = Database["public"]["Functions"]["mes_reservations"]["Returns"][number];
export type Statut = Ligne["statut"];

export type MaReservation = {
  id: string;
  prestation: string;
  prix: number;
  dureeMinutes: number;
  coiffeur: string;
  debut: string;
  statut: Statut;
  annulable: boolean;
};

export async function lireMesReservations(
  supabase: Client,
  salonId: string,
): Promise<MaReservation[] | null> {
  const { data, error } = await supabase.rpc("mes_reservations", { p_salon: salonId });
  if (error) return null;
  return data.map((r) => ({
    id: r.id,
    prestation: r.prestation,
    prix: r.prix,
    dureeMinutes: r.duree_minutes,
    coiffeur: r.coiffeur,
    debut: r.debut,
    statut: r.statut,
    annulable: r.annulable,
  }));
}

// À venir : confirmées et pas encore commencées, la plus proche d'abord.
// Historique : tout le reste (passées, terminées, annulées), la plus récente
// d'abord.
export function separer(
  reservations: MaReservation[],
  maintenant: Date,
): { aVenir: MaReservation[]; historique: MaReservation[] } {
  const aVenir = reservations.filter(
    (r) => r.statut === "confirmee" && new Date(r.debut) > maintenant,
  );
  const historique = reservations.filter((r) => !aVenir.includes(r)).reverse();
  return { aVenir, historique };
}

// Délai d'annulation du salon passé (#118) : réservation à venir, plus
// annulable. Message à la place du bouton « Annuler » ; null sinon (la base
// décide, `annulable` ; le délai ne sert qu'au texte).
export function messageDelaiPasse(
  reservation: MaReservation,
  maintenant: Date,
  delaiMinutes: number,
): string | null {
  const aVenir = reservation.statut === "confirmee" && new Date(reservation.debut) > maintenant;
  if (!aVenir || reservation.annulable || delaiMinutes <= 0) return null;
  return `Annulation possible jusqu'à ${formatDuree(delaiMinutes)} avant le rendez-vous. Contactez le salon.`;
}

// Une réservation confirmée dont l'heure est passée n'a pas encore été
// clôturée par le coiffeur : pour le client, elle est passée.
export function libelleStatut(statut: Statut, debut: string, maintenant: Date): string {
  switch (statut) {
    case "confirmee":
      return new Date(debut) > maintenant ? "Confirmée" : "Passée";
    case "terminee":
      return "Terminée";
    case "annulee":
      return "Annulée";
    case "absent":
      return "Non honorée";
  }
}

export type ResultatAnnulation = "annulee" | "impossible" | "deconnecte" | "erreur";

// PT409 : plus annulable (commencée entre-temps, déjà annulée...) ;
// PT404 : introuvable pour ce compte, traité de la même façon.
export async function annuler(supabase: Client, id: string): Promise<ResultatAnnulation> {
  const { error } = await supabase.rpc("annuler_reservation", { p_reservation: id });
  if (!error) return "annulee";
  if (error.code === "PT409" || error.code === "PT404") return "impossible";
  if (error.code === "PT401") return "deconnecte";
  return "erreur";
}
