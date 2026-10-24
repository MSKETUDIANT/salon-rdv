// Données de la charte affichées par /charte. Les valeurs doivent rester
// identiques aux jetons de app/globals.css : lib/charte.test.ts le vérifie.
// Les classes sont écrites en entier pour que Tailwind les détecte.

export const couleurs = [
  { jeton: "fond", valeur: "#FAFAF7", usage: "fond de page", classe: "bg-fond" },
  { jeton: "surface", valeur: "#FFFFFF", usage: "cartes, champs", classe: "bg-surface" },
  { jeton: "texte", valeur: "#1A1A1A", usage: "texte principal", classe: "bg-texte" },
  { jeton: "texte-secondaire", valeur: "#5C5C5C", usage: "durées, aides, mentions", classe: "bg-texte-secondaire" },
  { jeton: "bordure", valeur: "#8A8A8A", usage: "bordure des champs, cartes cliquables", classe: "bg-bordure" },
  { jeton: "separateur", valeur: "#E5E3DE", usage: "traits décoratifs, créneaux indisponibles", classe: "bg-separateur" },
  { jeton: "accent", valeur: "#1F5C4A", usage: "bouton principal, liens, focus, succès", classe: "bg-accent" },
  { jeton: "accent-survol", valeur: "#174536", usage: "survol du bouton principal", classe: "bg-accent-survol" },
  { jeton: "erreur", valeur: "#B42318", usage: "messages et bordures d'erreur", classe: "bg-erreur" },
] as const;

export type Jeton = (typeof couleurs)[number]["jeton"];

// Couples premier plan / fond utilisés, avec leur seuil WCAG 2.2 AA.
export const couples: { avant: Jeton; fond: Jeton; seuil: number; usage: string }[] = [
  { avant: "texte", fond: "fond", seuil: 4.5, usage: "texte principal" },
  { avant: "texte", fond: "surface", seuil: 4.5, usage: "texte principal sur carte" },
  { avant: "texte-secondaire", fond: "fond", seuil: 4.5, usage: "texte secondaire" },
  { avant: "texte-secondaire", fond: "surface", seuil: 4.5, usage: "texte secondaire sur carte" },
  { avant: "bordure", fond: "fond", seuil: 3, usage: "bordure de champ (composant)" },
  { avant: "bordure", fond: "surface", seuil: 3, usage: "bordure de champ sur carte" },
  { avant: "accent", fond: "fond", seuil: 4.5, usage: "lien, focus" },
  { avant: "accent", fond: "surface", seuil: 4.5, usage: "lien sur carte" },
  { avant: "surface", fond: "accent", seuil: 4.5, usage: "texte du bouton principal" },
  { avant: "surface", fond: "accent-survol", seuil: 4.5, usage: "bouton principal survolé" },
  { avant: "erreur", fond: "fond", seuil: 4.5, usage: "message d'erreur" },
  { avant: "erreur", fond: "surface", seuil: 4.5, usage: "message d'erreur sur carte" },
  { avant: "texte-secondaire", fond: "separateur", seuil: 4.5, usage: "créneau indisponible" },
];

export const tailles = [
  { classe: "text-base", px: 16 },
  { classe: "text-lg", px: 18 },
  { classe: "text-xl", px: 22 },
  { classe: "text-2xl", px: 28 },
  { classe: "text-3xl", px: 36 },
] as const;

export function valeur(jeton: Jeton): string {
  return couleurs.find((c) => c.jeton === jeton)!.valeur;
}
