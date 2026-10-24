// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { Carte } from "@/components/ui/carte";

afterEach(cleanup);

describe("Carte", () => {
  it("rend son contenu sur fond surface, bordure décorative separateur", () => {
    render(<Carte data-testid="carte">Coupe femme</Carte>);
    const carte = screen.getByTestId("carte");
    expect(carte.textContent).toBe("Coupe femme");
    expect(carte.className).toContain("bg-surface");
    expect(carte.className).toContain("border-separateur");
  });

  it("cliquable : bordure bordure (3:1), pas separateur", () => {
    render(<Carte data-testid="carte" cliquable>Coupe femme</Carte>);
    const classes = screen.getByTestId("carte").className;
    expect(classes).toContain("border-bordure");
    expect(classes).not.toContain("border-separateur");
  });
});
