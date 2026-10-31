import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { couleurs, couples, valeur } from "@/lib/charte";
import { contraste } from "@/lib/contraste";

const css = readFileSync(new URL("../app/globals.css", import.meta.url), "utf8");
const lire = (texte: string) =>
  new Map(
    [...texte.matchAll(/--color-([a-z-]+):\s*(#[0-9A-Fa-f]{6});/g)].map(([, nom, hex]) => [nom, hex.toUpperCase()]),
  );
// Mode clair : le bloc @theme ; mode sombre : le bloc prefers-color-scheme (issue 21).
const debutSombre = css.indexOf("@media (prefers-color-scheme: dark)");
const jetons = lire(css.slice(0, debutSombre));
const jetonsSombres = lire(css.slice(debutSombre));

describe("jetons de couleur", () => {
  it("globals.css définit exactement les 9 couleurs de la charte", () => {
    expect([...jetons.keys()].sort()).toEqual(couleurs.map((c) => c.jeton).sort());
  });

  it.each(couleurs)("$jeton a la même valeur dans globals.css et lib/charte.ts", ({ jeton, valeur }) => {
    expect(jetons.get(jeton)).toBe(valeur);
  });

  it("mode sombre : les 9 mêmes jetons, avec les valeurs de lib/charte.ts (issue 21)", () => {
    expect(debutSombre).toBeGreaterThan(0);
    expect(Object.fromEntries(jetonsSombres)).toEqual(
      Object.fromEntries(couleurs.map((c) => [c.jeton, c.sombre])),
    );
  });
});

describe("contrastes WCAG 2.2 AA (BNF-11)", () => {
  it.each(couples)("$avant sur $fond atteint $seuil:1 ($usage)", ({ avant, fond, seuil }) => {
    expect(contraste(valeur(avant), valeur(fond))).toBeGreaterThanOrEqual(seuil);
  });

  it.each(couples)("mode sombre : $avant sur $fond atteint $seuil:1 ($usage)", ({ avant, fond, seuil }) => {
    expect(contraste(valeur(avant, "sombre"), valeur(fond, "sombre"))).toBeGreaterThanOrEqual(seuil);
  });
});

describe("contraste", () => {
  it("noir sur blanc vaut 21:1, une couleur sur elle-même 1:1", () => {
    expect(contraste("#000000", "#FFFFFF")).toBeCloseTo(21, 5);
    expect(contraste("#1F5C4A", "#1F5C4A")).toBeCloseTo(1, 5);
  });
});
