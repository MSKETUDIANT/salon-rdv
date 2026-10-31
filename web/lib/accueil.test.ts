import { describe, expect, it } from "vitest";
import {
  adresseAccueil,
  lienItineraire,
  lienTelephone,
  semaineHoraires,
  titreAccueil,
} from "@/lib/accueil";

describe("titreAccueil", () => {
  it("affiche le nom du salon", () => {
    expect(titreAccueil({ nom: "Salon de démo" })).toBe("Salon cassé exprès");
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

describe("lienTelephone", () => {
  it("garde les chiffres et le + du début", () => {
    expect(lienTelephone("+216 71.234-567")).toBe("tel:+21671234567");
    expect(lienTelephone("71 234 567")).toBe("tel:71234567");
  });
});

describe("semaineHoraires", () => {
  it("donne les sept jours, Fermé quand le salon ne travaille pas", () => {
    const semaine = semaineHoraires([
      { jour: 1, ouverture: "09:00", fermeture: "19:00" },
      { jour: 6, ouverture: "10:00", fermeture: "18:00" },
    ]);
    expect(semaine).toHaveLength(7);
    expect(semaine[0]).toEqual({ jour: "Lundi", heures: "09:00 – 19:00" });
    expect(semaine[1]).toEqual({ jour: "Mardi", heures: "Fermé" });
    expect(semaine[5]).toEqual({ jour: "Samedi", heures: "10:00 – 18:00" });
    expect(semaine[6]).toEqual({ jour: "Dimanche", heures: "Fermé" });
  });

  it("n'affiche rien si le salon n'a aucun horaire", () => {
    expect(semaineHoraires([])).toEqual([]);
  });
});
