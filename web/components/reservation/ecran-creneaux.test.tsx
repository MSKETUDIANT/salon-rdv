// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { EcranCreneaux } from "@/components/reservation/ecran-creneaux";
import type { Catalogue } from "@/lib/catalogue";

vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams("prestation=p1"),
}));

const catalogue: Catalogue = {
  fuseau: "Africa/Tunis",
  prestations: [{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }],
  coiffeurs: [{ id: "a", nom: "Amira", prestations: ["p1"] }],
};

beforeEach(() => {
  // Lundi 26 octobre 2026, 7h à Tunis.
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-10-26T06:00:00Z"));
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "cle-anon");
  // Rien lundi ; mardi 9h ; mercredi 10h et 10h15.
  const creneaux = [
    { coiffeur_id: "a", debut: "2026-10-27T08:00:00+00:00", fin: "2026-10-27T08:45:00+00:00" },
    { coiffeur_id: "a", debut: "2026-10-28T09:00:00+00:00", fin: "2026-10-28T09:45:00+00:00" },
    { coiffeur_id: "a", debut: "2026-10-28T09:15:00+00:00", fin: "2026-10-28T10:00:00+00:00" },
  ];
  vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify(creneaux))));
});

afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
});

describe("EcranCreneaux", () => {
  it("prix sans millimes, bande de 14 jours, premier jour disponible choisi", async () => {
    render(<EcranCreneaux catalogue={catalogue} />);

    expect(screen.getByText(/45 min · 35\sDT/)).toBeTruthy();
    const titre = await screen.findByRole("heading", { level: 2 });
    expect(titre.textContent).toBe("Mardi 27 octobre");
    expect(screen.getByRole("button", { name: "Mardi 27 octobre" }).getAttribute("aria-pressed")).toBe("true");
    expect(screen.getByLabelText("Lundi 26 octobre : aucun créneau")).toBeTruthy();
    expect(screen.getByRole("group", { name: "Jour" }).querySelectorAll("li")).toHaveLength(14);
    expect(screen.getAllByRole("link", { name: /^\d{2}:\d{2}$/ }).map((l) => l.textContent)).toEqual(["09:00"]);
  });

  it("un seul jour affiché à la fois : choisir mercredi remplace mardi", async () => {
    render(<EcranCreneaux catalogue={catalogue} />);
    await screen.findByRole("heading", { level: 2 });

    fireEvent.click(screen.getByRole("button", { name: "Mercredi 28 octobre" }));
    expect(screen.getAllByRole("heading", { level: 2 }).map((h) => h.textContent)).toEqual(["Mercredi 28 octobre"]);
    expect(screen.getAllByRole("link", { name: /^\d{2}:\d{2}$/ }).map((l) => l.textContent)).toEqual(["10:00", "10:15"]);
  });
});
