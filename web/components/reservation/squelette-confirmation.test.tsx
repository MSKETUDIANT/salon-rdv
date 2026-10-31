// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { SqueletteConfirmation } from "@/components/reservation/squelette-confirmation";

afterEach(cleanup);

describe("SqueletteConfirmation (issue 131)", () => {
  it("annoncé « Chargement » aux lecteurs d'écran, sans titre ni lien lus en double", () => {
    render(<SqueletteConfirmation />);
    expect(screen.getByRole("status").textContent).toContain("Chargement de la réservation…");
    // La forme visible est cachée aux lecteurs d'écran : ni titre, ni lien.
    expect(screen.queryByRole("heading")).toBeNull();
    expect(screen.queryByRole("link")).toBeNull();
  });

  it("reprend les intitulés connus de l'écran 3", () => {
    render(<SqueletteConfirmation />);
    for (const texte of ["Confirmer la réservation", "Prestation", "Prix", "Vos coordonnées"]) {
      expect(screen.getByText(texte)).toBeTruthy();
    }
  });
});
