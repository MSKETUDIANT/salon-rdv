export type Prestation = { id: string; nom: string; prix: number; dureeMinutes: number };
export type Coiffeur = { id: string; nom: string; prestations: string[] };
export type Catalogue = { fuseau: string; prestations: Prestation[]; coiffeurs: Coiffeur[] };

// BF-C3 : seuls les coiffeurs qui savent faire la prestation sont proposés.
export function coiffeursCompetents(catalogue: Catalogue, prestationId: string): Coiffeur[] {
  return catalogue.coiffeurs.filter((c) => c.prestations.includes(prestationId));
}
