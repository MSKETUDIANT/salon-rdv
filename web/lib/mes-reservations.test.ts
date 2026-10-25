import { describe, expect, it, vi } from "vitest";
import {
  annuler,
  libelleStatut,
  lireMesReservations,
  separer,
  type MaReservation,
} from "@/lib/mes-reservations";

const maintenant = new Date("2026-10-25T12:00:00Z");

function reservation(id: string, debut: string, statut: MaReservation["statut"]): MaReservation {
  return {
    id,
    prestation: "Coupe",
    prix: 20,
    dureeMinutes: 30,
    coiffeur: "Amira",
    debut,
    statut,
    annulable: statut === "confirmee" && new Date(debut) > maintenant,
  };
}

// Dans l'ordre renvoyé par la fonction SQL : par date.
const passee = reservation("passee", "2026-10-20T09:00:00Z", "confirmee");
const terminee = reservation("terminee", "2026-10-22T09:00:00Z", "terminee");
const enCours = reservation("en-cours", "2026-10-25T11:45:00Z", "confirmee");
const prochaine = reservation("prochaine", "2026-10-27T09:00:00Z", "confirmee");
const annulee = reservation("annulee", "2026-10-28T09:00:00Z", "annulee");
const suivante = reservation("suivante", "2026-10-30T09:00:00Z", "confirmee");
const toutes = [passee, terminee, enCours, prochaine, annulee, suivante];

describe("separer", () => {
  it("à venir : confirmées pas encore commencées, la plus proche d'abord", () => {
    expect(separer(toutes, maintenant).aVenir.map((r) => r.id)).toEqual(["prochaine", "suivante"]);
  });

  it("historique : passées, commencées, terminées, annulées, la plus récente d'abord", () => {
    expect(separer(toutes, maintenant).historique.map((r) => r.id)).toEqual([
      "annulee",
      "en-cours",
      "terminee",
      "passee",
    ]);
  });

  it("aucune réservation", () => {
    expect(separer([], maintenant)).toEqual({ aVenir: [], historique: [] });
  });
});

describe("libelleStatut", () => {
  it("confirmée à venir ou passée, terminée, annulée, absent", () => {
    expect(libelleStatut("confirmee", prochaine.debut, maintenant)).toBe("Confirmée");
    expect(libelleStatut("confirmee", passee.debut, maintenant)).toBe("Passée");
    expect(libelleStatut("terminee", terminee.debut, maintenant)).toBe("Terminée");
    expect(libelleStatut("annulee", annulee.debut, maintenant)).toBe("Annulée");
    expect(libelleStatut("absent", passee.debut, maintenant)).toBe("Non honorée");
  });
});

function client(rpc: unknown) {
  return { rpc: vi.fn().mockResolvedValue(rpc) } as unknown as Parameters<typeof annuler>[0] & {
    rpc: ReturnType<typeof vi.fn>;
  };
}

describe("lireMesReservations", () => {
  it("appelle mes_reservations pour le salon ; colonnes renommées", async () => {
    const supabase = client({
      data: [
        {
          id: "r1",
          prestation: "Coupe",
          prix: 20,
          duree_minutes: 30,
          coiffeur: "Amira",
          debut: prochaine.debut,
          fin: "2026-10-27T09:30:00Z",
          statut: "confirmee",
          annulable: true,
        },
      ],
      error: null,
    });
    expect(await lireMesReservations(supabase, "s1")).toEqual([{ ...prochaine, id: "r1" }]);
    expect(supabase.rpc).toHaveBeenCalledWith("mes_reservations", { p_salon: "s1" });
  });

  it("erreur : null", async () => {
    expect(await lireMesReservations(client({ data: null, error: { code: "500" } }), "s1")).toBeNull();
  });
});

describe("annuler", () => {
  it("appelle annuler_reservation avec le seul id", async () => {
    const supabase = client({ data: [{ id: "r1", statut: "annulee" }], error: null });
    expect(await annuler(supabase, "r1")).toBe("annulee");
    expect(supabase.rpc).toHaveBeenCalledWith("annuler_reservation", { p_reservation: "r1" });
  });

  it("PT409 et PT404 : impossible ; PT401 : déconnecté ; autre : erreur", async () => {
    expect(await annuler(client({ error: { code: "PT409" } }), "r1")).toBe("impossible");
    expect(await annuler(client({ error: { code: "PT404" } }), "r1")).toBe("impossible");
    expect(await annuler(client({ error: { code: "PT401" } }), "r1")).toBe("deconnecte");
    expect(await annuler(client({ error: { code: "500" } }), "r1")).toBe("erreur");
  });
});
