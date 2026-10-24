import { describe, expect, it } from "vitest";
import { formatDuree, formatPrix } from "@/lib/format";

// Intl sépare le montant et la devise par une espace insécable.
const espaces = (texte: string) => texte.replace(/\s/g, " ");

describe("formatPrix", () => {
  it("sans décimales quand les millimes sont à zéro", () => {
    expect(espaces(formatPrix(35))).toBe("35 DT");
    expect(espaces(formatPrix(80))).toBe("80 DT");
  });

  it("avec les 3 décimales sinon", () => {
    expect(espaces(formatPrix(12.5))).toBe("12,500 DT");
    expect(espaces(formatPrix(7.25))).toBe("7,250 DT");
    expect(espaces(formatPrix(0.005))).toBe("0,005 DT");
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
