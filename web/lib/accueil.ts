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
