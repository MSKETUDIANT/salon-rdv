// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it } from "vitest";
import { Champ } from "@/components/ui/champ";

afterEach(cleanup);

describe("Champ", () => {
  it("relie le libellé au champ, sans erreur par défaut", () => {
    render(<Champ libelle="Adresse e-mail" type="email" />);
    const champ = screen.getByLabelText("Adresse e-mail");
    expect(champ.getAttribute("aria-invalid")).toBeNull();
    expect(champ.getAttribute("aria-describedby")).toBeNull();
    expect(champ.className).toContain("border-bordure");
  });

  it("en erreur : aria-invalid, message relié au champ, bordure erreur", () => {
    render(<Champ libelle="Code" erreur="Le code doit contenir 6 chiffres." />);
    const champ = screen.getByLabelText("Code");
    expect(champ.getAttribute("aria-invalid")).toBe("true");
    const message = document.getElementById(champ.getAttribute("aria-describedby")!);
    expect(message?.textContent).toBe("Le code doit contenir 6 chiffres.");
    expect(champ.className).toContain("border-erreur");
  });

  it("est atteint au clavier et porte le focus de la charte", async () => {
    render(<Champ libelle="Adresse e-mail" />);
    await userEvent.tab();
    const champ = screen.getByLabelText("Adresse e-mail");
    expect(document.activeElement).toBe(champ);
    expect(champ.className).toContain("focus-visible:outline-accent");
  });
});
