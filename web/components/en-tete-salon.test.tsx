// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { EnTeteSalon } from "@/components/en-tete-salon";

afterEach(cleanup);

describe("EnTeteSalon (issue 129)", () => {
  it("affiche l'adresse et le lien Itinéraire vers Google Maps", () => {
    render(<EnTeteSalon nom="Salon de démo" adresse="1 rue de la Coupe" />);
    expect(screen.getByText("1 rue de la Coupe")).toBeTruthy();
    const lien = screen.getByRole("link", { name: "Itinéraire vers le salon (Google Maps)" });
    expect(lien.getAttribute("href")).toBe(
      "https://www.google.com/maps/search/?api=1&query=1%20rue%20de%20la%20Coupe",
    );
  });

  it("sans adresse, ni adresse ni lien Itinéraire", () => {
    render(<EnTeteSalon nom="Salon de démo" adresse={null} />);
    expect(screen.queryByText(/Adresse/)).toBeNull();
    expect(screen.queryByRole("link", { name: /Itinéraire/ })).toBeNull();
    expect(screen.queryByRole("link", { name: /Appeler/ })).toBeNull();
    expect(screen.getByRole("link", { name: "Réserver" })).toBeTruthy();
  });

  it("affiche le téléphone, à toucher pour appeler", () => {
    render(<EnTeteSalon nom="Salon de démo" adresse={null} telephone="+216 71 234 567" />);
    const lien = screen.getByRole("link", { name: "Appeler le salon au +216 71 234 567" });
    expect(lien.getAttribute("href")).toBe("tel:+21671234567");
    expect(lien.textContent).toBe("+216 71 234 567");
  });

  it("« Réserver » mène à la cible donnée (liste de l'accueil, option A)", () => {
    render(<EnTeteSalon nom="Salon de démo" adresse={null} reserver="#prestations" />);
    expect(screen.getByRole("link", { name: "Réserver" }).getAttribute("href")).toBe(
      "#prestations",
    );
  });
});
