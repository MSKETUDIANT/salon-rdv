// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { BarreOnglets, EnTeteNavigation } from "@/components/navigation/navigation-site";

const etat = vi.hoisted(() => ({ chemin: "/" }));
vi.mock("next/navigation", () => ({ usePathname: () => etat.chemin }));

afterEach(cleanup);

function onglets() {
  return within(screen.getByRole("navigation", { name: "Navigation principale" })).getAllByRole("link");
}

describe("Navigation du site (#53)", () => {
  it("barre d'onglets : Accueil, Réserver, Mes réservations, avec leur adresse", () => {
    render(<BarreOnglets />);
    expect(onglets().map((l) => [l.textContent, l.getAttribute("href")])).toEqual([
      ["Accueil", "/"],
      ["Réserver", "/reserver"],
      ["Mes réservations", "/mes-reservations"],
    ]);
    // Icônes décoratives : le libellé suffit aux lecteurs d'écran.
    for (const icone of document.querySelectorAll("svg")) expect(icone.getAttribute("aria-hidden")).toBe("true");
  });

  it("onglet courant : la page, ou toute étape du parcours de réservation", () => {
    for (const [chemin, attendu] of [
      ["/", "Accueil"],
      ["/reserver", "Réserver"],
      ["/reserver/creneaux", "Réserver"],
      ["/reserver/confirmation", "Réserver"],
      ["/mes-reservations", "Mes réservations"],
    ]) {
      etat.chemin = chemin;
      render(<BarreOnglets />);
      expect(onglets().filter((l) => l.getAttribute("aria-current") === "page").map((l) => l.textContent)).toEqual([
        attendu,
      ]);
      cleanup();
    }
  });

  it("onglet courant : pastille derrière l'icône, aucune sur les autres (#55)", () => {
    etat.chemin = "/reserver";
    render(<BarreOnglets />);
    const pastilles = onglets().map((l) => l.querySelector("span")?.className.includes("bg-separateur"));
    expect(pastilles).toEqual([false, true, false]);
  });

  it("page hors navigation (charte) : aucun onglet courant", () => {
    etat.chemin = "/charte";
    render(<BarreOnglets />);
    expect(onglets().some((l) => l.hasAttribute("aria-current"))).toBe(false);
  });

  it("en-tête : logo « Salon RDV » vers l'accueil, mêmes liens, onglet courant", () => {
    etat.chemin = "/mes-reservations";
    render(<EnTeteNavigation />);
    // Logo en tracés, nommé pour les lecteurs d'écran (#55).
    expect(screen.getByRole("img", { name: "Salon RDV" })).toBeTruthy();
    expect(screen.getByRole("link", { name: "Salon RDV" }).getAttribute("href")).toBe("/");
    expect(onglets().map((l) => l.textContent)).toEqual(["Accueil", "Réserver", "Mes réservations"]);
    expect(screen.getByRole("link", { name: "Mes réservations" }).getAttribute("aria-current")).toBe("page");
  });
});
