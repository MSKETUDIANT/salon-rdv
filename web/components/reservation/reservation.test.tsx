// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { CartePrestation } from "@/components/reservation/carte-prestation";
import { ListeCreneaux } from "@/components/reservation/liste-creneaux";
import { coiffeursCompetents, type Catalogue } from "@/lib/catalogue";

afterEach(cleanup);

describe("CartePrestation", () => {
  it("nom, durée et prix ; toute la carte mène aux créneaux", () => {
    render(
      <CartePrestation prestation={{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }} />,
    );
    const lien = screen.getByRole("link");
    expect(lien.getAttribute("href")).toBe("/reserver/creneaux?prestation=p1");
    expect(lien.textContent?.replace(/\s/g, " ")).toBe("Coupe femme45 min · 35,000 DT");
  });
});

describe("ListeCreneaux", () => {
  const jours = [
    {
      cle: "2026-10-26",
      libelle: "Lundi 26 octobre",
      heures: [
        { debut: "2026-10-26T08:00:00.000Z", libelle: "09:00" },
        { debut: "2026-10-26T08:15:00.000Z", libelle: "09:15" },
      ],
    },
    {
      cle: "2026-10-27",
      libelle: "Mardi 27 octobre",
      heures: [{ debut: "2026-10-27T09:00:00.000Z", libelle: "10:00" }],
    },
  ];

  it("un titre par jour, une heure cliquable par créneau", () => {
    render(<ListeCreneaux jours={jours} prestationId="p1" />);
    const titres = screen.getAllByRole("heading", { level: 2 });
    expect(titres.map((t) => t.textContent)).toEqual(["Lundi 26 octobre", "Mardi 27 octobre"]);

    const lundi = screen.getByRole("region", { name: "Lundi 26 octobre" });
    expect(within(lundi).getAllByRole("link").map((l) => l.textContent)).toEqual(["09:00", "09:15"]);
  });

  it("chaque heure mène à la confirmation avec le coiffeur choisi", () => {
    render(<ListeCreneaux jours={jours} prestationId="p1" coiffeurId="c1" />);
    const lien = screen.getByRole("link", { name: "10:00" });
    expect(lien.getAttribute("href")).toBe(
      "/reserver/confirmation?prestation=p1&debut=2026-10-27T09%3A00%3A00.000Z&coiffeur=c1",
    );
  });

  it("zones tactiles de 48 px et chiffres à chasse fixe", () => {
    render(<ListeCreneaux jours={jours} prestationId="p1" />);
    const classes = screen.getByRole("link", { name: "09:00" }).className;
    expect(classes).toContain("h-12");
    expect(classes).toContain("tabular-nums");
  });
});

describe("coiffeursCompetents", () => {
  it("BF-C3 : seuls les coiffeurs qui savent faire la prestation", () => {
    const catalogue: Catalogue = {
      fuseau: "Africa/Tunis",
      prestations: [],
      coiffeurs: [
        { id: "a", nom: "Amira", prestations: ["coupe", "couleur"] },
        { id: "y", nom: "Youssef", prestations: ["coupe"] },
      ],
    };
    expect(coiffeursCompetents(catalogue, "couleur").map((c) => c.nom)).toEqual(["Amira"]);
    expect(coiffeursCompetents(catalogue, "coupe").map((c) => c.nom)).toEqual(["Amira", "Youssef"]);
  });
});
