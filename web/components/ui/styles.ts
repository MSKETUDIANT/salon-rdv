// Classes partagées par les composants de la charte (docs/charte-graphique.md §4).

// Focus clavier : contour accent 2 px, décalé de 2 px, sur tout élément interactif.
export const focus =
  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent";

// Boutons : 48 px de haut, au moins 44 px de large, coins 8 px.
const baseBouton = `inline-flex h-12 min-w-11 items-center justify-center rounded-base px-5 text-base font-semibold ${focus}`;

export const classesBouton = {
  principal: `${baseBouton} bg-accent text-surface hover:bg-accent-survol`,
  secondaire: `${baseBouton} border border-bordure bg-surface text-texte hover:bg-fond`,
} as const;

export type VarianteBouton = keyof typeof classesBouton;
