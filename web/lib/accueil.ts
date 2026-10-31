// Titre de la page d'accueil selon le salon lu (ou absent).
export function titreAccueil(salon: { nom: string } | null): string {
  const nom = salon?.nom.trim();
  return nom ? nom : "Salon introuvable";
}

// Adresse affichée sur l'accueil (#129) : null si absente ou vide.
export function adresseAccueil(salon: { adresse: string | null } | null): string | null {
  const adresse = salon?.adresse?.trim();
  return adresse ? adresse : null;
}

// Lien « Itinéraire » vers Google Maps (#129) : adresse universelle, ouverte
// par l'application Maps sur un téléphone, par le site sur un ordinateur.
export function lienItineraire(adresse: string): string {
  return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(adresse)}`;
}

// Lien d'appel (#129) : chiffres seuls, « + » gardé au début.
export function lienTelephone(telephone: string): string {
  const plus = telephone.trim().startsWith("+") ? "+" : "";
  return `tel:${plus}${telephone.replace(/\D/g, "")}`;
}

const JOURS = ["Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"];

// Semaine complète, du lundi au dimanche, comme Google Maps (#129) : heures
// d'ouverture du jour, ou « Fermé ». Vide si le salon n'a aucun horaire (rien
// à afficher plutôt que sept « Fermé »).
export function semaineHoraires(
  horaires: { jour: number; ouverture: string; fermeture: string }[],
): { jour: string; heures: string }[] {
  if (horaires.length === 0) return [];
  return JOURS.map((jour, i) => {
    const h = horaires.find((x) => x.jour === i + 1);
    return { jour, heures: h ? `${h.ouverture} – ${h.fermeture}` : "Fermé" };
  });
}
