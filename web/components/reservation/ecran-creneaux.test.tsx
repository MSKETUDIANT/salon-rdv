// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { EcranCreneaux } from "@/components/reservation/ecran-creneaux";
import type { Catalogue } from "@/lib/catalogue";

const etat = vi.hoisted(() => ({ recherche: "prestation=p1" }));
vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams(etat.recherche),
}));

const catalogue: Catalogue = {
  fuseau: "Africa/Tunis",
  prestations: [{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }],
  coiffeurs: [{ id: "a", nom: "Amira", prestations: ["p1"] }],
};

beforeEach(() => {
  etat.recherche = "prestation=p1";
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

  it("filtre coiffeur repris de l'URL (retour de l'écran 3) ; ignoré s'il n'est pas valable", async () => {
    etat.recherche = "prestation=p1&coiffeur=a";
    render(<EcranCreneaux catalogue={catalogue} />);
    expect((screen.getByLabelText("Coiffeur") as HTMLSelectElement).value).toBe("a");
    await screen.findByRole("heading", { level: 2 });
    expect(vi.mocked(fetch).mock.calls[0][0]).toContain("p_coiffeur=a");
    cleanup();

    etat.recherche = "prestation=p1&coiffeur=inconnu";
    render(<EcranCreneaux catalogue={catalogue} />);
    expect((screen.getByLabelText("Coiffeur") as HTMLSelectElement).value).toBe("");
  });

  it("retour après un refus (pris=1) : message en tête, liste relue sans la lecture anticipée", async () => {
    // Lecture anticipée périmée qui proposerait encore le créneau pris.
    const perime = [{ coiffeur_id: "a", debut: "2026-10-27T07:00:00+00:00", fin: "2026-10-27T07:45:00+00:00" }];
    (window as unknown as Record<string, unknown>).__creneauxPrecharges = {
      prestation: "p1",
      du: "2026-10-26",
      au: "2026-11-08",
      promesse: Promise.resolve(perime),
    };
    etat.recherche = "prestation=p1&pris=1";
    render(<EcranCreneaux catalogue={catalogue} />);

    expect(screen.getByRole("alert").textContent).toBe("Ce créneau vient d'être pris. Choisissez-en un autre.");
    await screen.findByRole("heading", { level: 2 });
    expect(vi.mocked(fetch)).toHaveBeenCalledTimes(1);
    expect(screen.getAllByRole("link", { name: /^\d{2}:\d{2}$/ }).map((l) => l.textContent)).toEqual(["09:00"]);
    delete (window as unknown as Record<string, unknown>).__creneauxPrecharges;
  });

  it("sans refus : pas de message", async () => {
    render(<EcranCreneaux catalogue={catalogue} />);
    await screen.findByRole("heading", { level: 2 });
    expect(screen.queryByRole("alert")).toBeNull();
  });
});
