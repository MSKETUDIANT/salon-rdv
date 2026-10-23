import { describe, expect, it } from "vitest";
import { nomDuSalon } from "@/lib/accueil";

const ID = "11111111-1111-1111-1111-111111111111";

describe("nomDuSalon", () => {
  it("renvoie le nom du salon", () => {
    expect(nomDuSalon({ nom: "Salon de démo" }, ID)).toBe("Salon de démo");
  });

  it("retire les espaces autour du nom", () => {
    expect(nomDuSalon({ nom: "  Salon de démo " }, ID)).toBe("Salon de démo");
  });

  it("échoue si le salon n'existe pas, en nommant l'id", () => {
    expect(() => nomDuSalon(null, ID)).toThrow(ID);
  });

  it("échoue si le nom est vide", () => {
    expect(() => nomDuSalon({ nom: "   " }, ID)).toThrow(ID);
  });
});
