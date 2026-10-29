import type { SupabaseClient } from "@supabase/supabase-js";
import { coiffeursCompetents, type Catalogue, type Coiffeur, type Prestation } from "@/lib/catalogue";
import type { Database } from "@/lib/database.types";

// Écran 3 (#6) : ce que le client s'apprête à réserver, lu dans l'URL
// (?prestation=&debut=&coiffeur=). Sans coiffeur : « Peu importe ».
export type Demande = { prestation: Prestation; debut: string; coiffeur?: Coiffeur };

export function lireDemande(params: URLSearchParams, catalogue: Catalogue): Demande | null {
  const prestation = catalogue.prestations.find((p) => p.id === params.get("prestation"));
  const debut = params.get("debut") ?? "";
  if (!prestation || Number.isNaN(Date.parse(debut))) return null;

  const coiffeurId = params.get("coiffeur");
  if (!coiffeurId) return { prestation, debut };
  const coiffeur = coiffeursCompetents(catalogue, prestation.id).find((c) => c.id === coiffeurId);
  return coiffeur ? { prestation, debut, coiffeur } : null;
}

// « Mardi 27 octobre » et « 10:00 », à l'heure du salon.
export function jourEtHeure(debut: string, fuseau: string): { jour: string; heure: string } {
  const instant = new Date(debut);
  const jour = new Intl.DateTimeFormat("fr-FR", {
    timeZone: fuseau,
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(instant);
  const heure = new Intl.DateTimeFormat("fr-FR", {
    timeZone: fuseau,
    hour: "2-digit",
    minute: "2-digit",
  }).format(instant);
  return { jour: jour.charAt(0).toUpperCase() + jour.slice(1), heure };
}

// Retour à l'écran 2 sans perdre la prestation ni le filtre coiffeur. pris :
// le créneau choisi vient d'être pris (#51) ; l'écran 2 relit alors la liste
// et l'annonce en tête.
export function lienCreneaux(prestationId: string, coiffeurId?: string, pris = false): string {
  const params = new URLSearchParams({ prestation: prestationId });
  if (coiffeurId) params.set("coiffeur", coiffeurId);
  if (pris) params.set("pris", "1");
  return `/reserver/creneaux?${params}`;
}

export function emailValide(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function codeValide(code: string): boolean {
  return /^\d{6}$/.test(code);
}

type Client = SupabaseClient<Database>;

// Messages des erreurs d'authentification (codes de Supabase Auth).
export function messageErreurAuth(code: string | undefined): string {
  switch (code) {
    case "otp_expired":
      return "Code incorrect ou expiré. Vérifiez-le, ou demandez un nouveau code.";
    case "otp_disabled":
      return "Aucun compte avec cette adresse. Le compte est créé lors de la première réservation.";
    case "over_email_send_rate_limit":
    case "over_request_rate_limit":
      return "Trop de demandes. Réessayez dans une minute.";
    default:
      return "Une erreur est survenue. Réessayez.";
  }
}

// Envoie le code à 6 chiffres. Avec un nom (écran de confirmation), crée le
// compte s'il n'existe pas ; le nom n'est enregistré que pour un nouveau
// compte. Sans nom (« Mes réservations », #7), connexion à un compte existant
// seulement.
export async function envoyerCode(supabase: Client, email: string, nom: string | null) {
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: nom === null ? { shouldCreateUser: false } : { shouldCreateUser: true, data: { nom } },
  });
  return error ? messageErreurAuth(error.code) : null;
}

export async function validerCode(supabase: Client, email: string, code: string) {
  const { error } = await supabase.auth.verifyOtp({ email, token: code, type: "email" });
  return error ? messageErreurAuth(error.code) : null;
}

export type ResultatReservation =
  | { statut: "confirmee"; coiffeurId: string }
  | { statut: "pris" }
  | { statut: "deconnecte" }
  | { statut: "occupe" }
  | { statut: "erreur" };

// Enregistre la réservation (fonction SQL reserver, qui revérifie la
// disponibilité). PT409 : le créneau vient d'être pris. 55P03 : trop de
// réservations au même moment pour ce coiffeur, verrou non obtenu en 3 s
// (#59, #71) : le client peut réessayer tel quel.
export async function reserver(supabase: Client, demande: Demande): Promise<ResultatReservation> {
  const { data, error } = await supabase.rpc("reserver", {
    p_prestation: demande.prestation.id,
    p_debut: demande.debut,
    p_coiffeur: demande.coiffeur?.id,
  });
  if (error) {
    if (error.code === "PT409") return { statut: "pris" };
    if (error.code === "PT401") return { statut: "deconnecte" };
    if (error.code === "55P03") return { statut: "occupe" };
    return { statut: "erreur" };
  }
  return data?.[0] ? { statut: "confirmee", coiffeurId: data[0].coiffeur_id } : { statut: "erreur" };
}
