// Nom du salon à afficher. Un salon absent (ou sans nom) est une erreur de
// configuration (NEXT_PUBLIC_SALON_ID) : elle fait échouer le build au lieu de
// publier une page vide.
export function nomDuSalon(salon: { nom: string } | null, salonId: string): string {
  const nom = salon?.nom.trim();
  if (!nom) {
    throw new Error(`Aucun salon avec l'id ${salonId} (vérifier NEXT_PUBLIC_SALON_ID)`);
  }
  return nom;
}
