// Titre de la page d'accueil selon le salon lu (ou absent).
export function titreAccueil(salon: { nom: string } | null): string {
  const nom = salon?.nom.trim();
  return nom ? nom : "Salon introuvable";
}
