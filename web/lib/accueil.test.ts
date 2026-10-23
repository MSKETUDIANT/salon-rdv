import { describe, expect, it } from "vitest";
import { titreAccueil } from "@/lib/accueil";

describe("titreAccueil", () => {
  it("affiche le nom du salon", () => {
    expect(titreAccueil({ nom: "Salon de démo" })).toBe("Salon de démo");
  });

  it("retire les espaces autour du nom", () => {
    expect(titreAccueil({ nom: "  Salon de démo " })).toBe("Salon de démo");
  });

  it("signale un salon absent", () => {
    expect(titreAccueil(null)).toBe("Salon introuvable");
  });

  it("signale un nom vide", () => {
    expect(titreAccueil({ nom: "   " })).toBe("Salon introuvable");
  });
});
