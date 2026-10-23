// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Bouton } from "@/components/ui/bouton";

afterEach(cleanup);

function formulaire(chargement: boolean) {
  const envoi = vi.fn((e: { preventDefault: () => void }) => e.preventDefault());
  const clic = vi.fn();
  render(
    <form onSubmit={envoi}>
      <label htmlFor="email">E-mail</label>
      <input id="email" />
      <Bouton type="submit" chargement={chargement} onClick={clic}>
        Confirmer
      </Bouton>
    </form>,
  );
  return { envoi, clic, bouton: screen.getByRole("button"), champ: screen.getByLabelText("E-mail") };
}

describe("Bouton", () => {
  it("rend les variantes principal et secondaire", () => {
    render(
      <>
        <Bouton>Principal</Bouton>
        <Bouton variante="secondaire">Secondaire</Bouton>
      </>,
    );
    expect(screen.getByRole("button", { name: "Principal" }).className).toContain("bg-accent");
    expect(screen.getByRole("button", { name: "Secondaire" }).className).toContain("border-bordure");
  });

  it("fait 48 px de haut et porte le focus de la charte", () => {
    render(<Bouton>Principal</Bouton>);
    const classes = screen.getByRole("button").className.split(" ");
    expect(classes).toEqual(
      expect.arrayContaining(["h-12", "focus-visible:outline-2", "focus-visible:outline-offset-2", "focus-visible:outline-accent"]),
    );
  });

  it("est atteint au clavier avec Tab", async () => {
    render(<Bouton>Principal</Bouton>);
    await userEvent.tab();
    expect(document.activeElement).toBe(screen.getByRole("button"));
  });

  it("hors chargement : un clic et Entrée envoient le formulaire (témoin)", async () => {
    const { envoi, clic, bouton, champ } = formulaire(false);
    await userEvent.click(bouton);
    await userEvent.type(champ, "{Enter}");
    expect(clic).toHaveBeenCalledTimes(2);
    expect(envoi).toHaveBeenCalledTimes(2);
  });

  it("en chargement : aria-busy, libellé de chargement, jamais disabled", () => {
    const { bouton } = formulaire(true);
    expect(bouton.getAttribute("aria-busy")).toBe("true");
    expect(bouton.textContent).toBe("Chargement…");
    expect(bouton.hasAttribute("disabled")).toBe(false);
  });

  it("en chargement : un double clic ne déclenche rien", async () => {
    const { envoi, clic, bouton } = formulaire(true);
    await userEvent.dblClick(bouton);
    expect(clic).not.toHaveBeenCalled();
    expect(envoi).not.toHaveBeenCalled();
  });

  it("en chargement : Entrée sur le bouton ou dans un champ ne déclenche rien", async () => {
    const { envoi, clic, bouton, champ } = formulaire(true);
    bouton.focus();
    await userEvent.keyboard("{Enter}");
    await userEvent.keyboard(" ");
    await userEvent.type(champ, "{Enter}");
    expect(clic).not.toHaveBeenCalled();
    expect(envoi).not.toHaveBeenCalled();
  });
});
