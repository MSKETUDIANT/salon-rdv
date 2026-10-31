import { describe, expect, it } from "vitest";
import { adresseAccueil, lienItineraire, titreAccueil } from "@/lib/accueil";

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

describe("adresseAccueil", () => {
  it("affiche l'adresse sans espaces autour", () => {
    expect(adresseAccueil({ adresse: " 1 rue de la Coupe " })).toBe("1 rue de la Coupe");
  });

  it("n'affiche rien sans salon, sans adresse ou avec une adresse vide", () => {
    expect(adresseAccueil(null)).toBeNull();
    expect(adresseAccueil({ adresse: null })).toBeNull();
    expect(adresseAccueil({ adresse: "  " })).toBeNull();
  });
});

describe("lienItineraire", () => {
  it("encode l'adresse dans le lien Google Maps", () => {
    expect(lienItineraire("1 rue de la Coupe, Tunis & Co")).toBe(
      "https://www.google.com/maps/search/?api=1&query=1%20rue%20de%20la%20Coupe%2C%20Tunis%20%26%20Co",
    );
  });
});
