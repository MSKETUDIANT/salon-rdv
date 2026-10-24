import { afterEach, describe, expect, it, vi } from "vitest";
import {
  ajouterJours,
  grouperParJour,
  jourLocal,
  lienConfirmation,
  lireCreneaux,
  periode,
} from "@/lib/creneaux";

afterEach(() => {
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("lireCreneaux", () => {
  it("appelle /api/creneaux sur la même origine, avec la clé anon", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "cle-anon");
    const fetch = vi.fn().mockResolvedValue(new Response("[]", { status: 200 }));
    vi.stubGlobal("fetch", fetch);

    await expect(
      lireCreneaux({ prestationId: "p1", du: "2026-10-26", au: "2026-11-08", coiffeurId: "c1" }),
    ).resolves.toEqual([]);
    expect(fetch).toHaveBeenCalledWith(
      "/api/creneaux?p_prestation=p1&p_du=2026-10-26&p_au=2026-11-08&p_coiffeur=c1",
      expect.objectContaining({ headers: { apikey: "cle-anon" } }),
    );
  });

  it("« Peu importe » : pas de p_coiffeur ; erreur HTTP levée", async () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "cle-anon");
    const fetch = vi.fn().mockResolvedValue(new Response("{}", { status: 500 }));
    vi.stubGlobal("fetch", fetch);

    await expect(
      lireCreneaux({ prestationId: "p1", du: "2026-10-26", au: "2026-11-08" }),
    ).rejects.toThrow("HTTP 500");
    expect(fetch.mock.calls[0][0]).not.toContain("p_coiffeur");
  });
});

const TUNIS = "Africa/Tunis"; // UTC+1

describe("jourLocal et periode", () => {
  it("prend la date du salon, pas celle d'UTC", () => {
    // 23h30 UTC le 26 = 0h30 le 27 à Tunis.
    expect(jourLocal(new Date("2026-10-26T23:30:00Z"), TUNIS)).toBe("2026-10-27");
  });

  it("période de 14 jours, aujourd'hui compris", () => {
    expect(periode(new Date("2026-10-26T10:00:00Z"), TUNIS)).toEqual({
      du: "2026-10-26",
      au: "2026-11-08",
    });
  });

  it("ajouterJours passe les fins de mois", () => {
    expect(ajouterJours("2026-10-31", 1)).toBe("2026-11-01");
  });
});

describe("grouperParJour", () => {
  const A = "aaaaaaaa-0000-0000-0000-000000000000";
  const B = "bbbbbbbb-0000-0000-0000-000000000000";

  it("tous les jours de la période, avec leurs créneaux à l'heure du salon", () => {
    const jours = grouperParJour(
      [
        { coiffeur_id: A, debut: "2026-10-28T09:00:00+00:00", fin: "2026-10-28T09:30:00+00:00" },
        { coiffeur_id: A, debut: "2026-10-26T08:15:00+00:00", fin: "2026-10-26T08:45:00+00:00" },
        { coiffeur_id: A, debut: "2026-10-26T08:00:00+00:00", fin: "2026-10-26T08:30:00+00:00" },
      ],
      TUNIS,
      "2026-10-26",
      3,
    );

    expect(jours.map((j) => j.cle)).toEqual(["2026-10-26", "2026-10-27", "2026-10-28"]);
    expect(jours[0]).toMatchObject({ libelle: "Lundi 26 octobre", court: "lun.", numero: "26" });
    expect(jours[0].heures.map((h) => h.libelle)).toEqual(["09:00", "09:15"]);
    expect(jours[1].heures).toEqual([]);
    expect(jours[2].heures.map((h) => h.libelle)).toEqual(["10:00"]);
  });

  it("14 jours par défaut", () => {
    expect(grouperParJour([], TUNIS, "2026-10-26")).toHaveLength(14);
  });

  it("créneau de 23h30 UTC : rangé au lendemain, jour local du salon", () => {
    const jours = grouperParJour(
      [{ coiffeur_id: A, debut: "2026-10-26T23:30:00+00:00", fin: "2026-10-27T00:00:00+00:00" }],
      TUNIS,
      "2026-10-26",
      2,
    );
    expect(jours[0].heures).toEqual([]);
    expect(jours[1].heures.map((h) => h.libelle)).toEqual(["00:30"]);
  });

  it("« Peu importe » : une heure proposée par deux coiffeurs n'apparaît qu'une fois", () => {
    const jours = grouperParJour(
      [
        { coiffeur_id: A, debut: "2026-10-26T08:00:00+00:00", fin: "2026-10-26T08:30:00+00:00" },
        { coiffeur_id: B, debut: "2026-10-26T08:00:00+00:00", fin: "2026-10-26T08:30:00+00:00" },
      ],
      TUNIS,
      "2026-10-26",
      1,
    );
    expect(jours[0].heures).toEqual([{ debut: "2026-10-26T08:00:00.000Z", libelle: "09:00" }]);
  });
});

describe("lienConfirmation", () => {
  it("passe la prestation, l'heure et le coiffeur choisi", () => {
    expect(lienConfirmation("p1", "2026-10-26T08:00:00.000Z", "c1")).toBe(
      "/reserver/confirmation?prestation=p1&debut=2026-10-26T08%3A00%3A00.000Z&coiffeur=c1",
    );
  });

  it("« Peu importe » : pas de coiffeur dans le lien", () => {
    expect(lienConfirmation("p1", "2026-10-26T08:00:00.000Z")).not.toContain("coiffeur");
  });
});
