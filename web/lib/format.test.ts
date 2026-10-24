import { describe, expect, it } from "vitest";
import { formatDuree, formatPrix } from "@/lib/format";

// Intl sépare le montant et la devise par une espace insécable.
const espaces = (texte: string) => texte.replace(/\s/g, " ");

describe("formatPrix", () => {
  it("affiche des dinars à 3 décimales", () => {
    expect(espaces(formatPrix(35))).toBe("35,000 DT");
    expect(espaces(formatPrix(12.5))).toBe("12,500 DT");
  });
});

describe("formatDuree", () => {
  it("minutes seules sous une heure", () => {
    expect(formatDuree(30)).toBe("30 min");
    expect(formatDuree(45)).toBe("45 min");
  });

  it("heures pleines et heures avec minutes", () => {
    expect(formatDuree(60)).toBe("1 h");
    expect(formatDuree(90)).toBe("1 h 30");
    expect(formatDuree(125)).toBe("2 h 05");
  });
});
