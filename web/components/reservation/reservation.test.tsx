// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { BandeJours } from "@/components/reservation/bande-jours";
import { CartePrestation, ListePrestations } from "@/components/reservation/carte-prestation";
import { ListeCreneaux } from "@/components/reservation/liste-creneaux";
import { coiffeursCompetents, type Catalogue } from "@/lib/catalogue";

afterEach(cleanup);

describe("CartePrestation", () => {
  it("nom, durée, prix et « Choisir » ; toute la ligne mène aux créneaux", () => {
    render(
      <CartePrestation prestation={{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }} />,
    );
    const lien = screen.getByRole("link");
    expect(lien.getAttribute("href")).toBe("/reserver/creneaux?prestation=p1");
    expect(lien.textContent?.replace(/\s/g, " ")).toBe("Coupe femme45 min·35 DTChoisir");
  });
});

describe("ListePrestations (issue 129)", () => {
  it("sur l'accueil : l'origine suit dans le lien vers l'écran 2", () => {
    render(
      <ListePrestations
        prestations={[{ id: "p1", nom: "Couleur", prix: 80, dureeMinutes: 90 }]}
        depuisAccueil
      />,
    );
    expect(screen.getByRole("link").getAttribute("href")).toBe(
      "/reserver/creneaux?prestation=p1&depuis=accueil",
    );
  });

  it("une ligne par prestation, dans l'ordre reçu", () => {
    render(
      <ListePrestations
        prestations={[
          { id: "p1", nom: "Couleur", prix: 80, dureeMinutes: 90 },
          { id: "p2", nom: "Coupe homme", prix: 20, dureeMinutes: 30 },
        ]}
      />,
    );
    const lignes = screen.getAllByRole("listitem");
    expect(lignes.map((l) => within(l).getByRole("link").getAttribute("href"))).toEqual([
      "/reserver/creneaux?prestation=p1",
      "/reserver/creneaux?prestation=p2",
    ]);
  });
});

const lundi = {
  cle: "2026-10-26",
  libelle: "Lundi 26 octobre",
  court: "lun.",
  numero: "26",
  heures: [
    { debut: "2026-10-26T08:00:00.000Z", libelle: "09:00" },
    { debut: "2026-10-26T08:15:00.000Z", libelle: "09:15" },
  ],
};
const mardi = { cle: "2026-10-27", libelle: "Mardi 27 octobre", court: "mar.", numero: "27", heures: [] };
const mercredi = {
  cle: "2026-10-28",
  libelle: "Mercredi 28 octobre",
  court: "mer.",
  numero: "28",
  heures: [{ debut: "2026-10-28T09:00:00.000Z", libelle: "10:00" }],
};

describe("ListeCreneaux", () => {
  it("le jour en titre, une heure cliquable par créneau", () => {
    render(<ListeCreneaux jour={lundi} prestationId="p1" />);
    expect(screen.getByRole("heading", { level: 2 }).textContent).toBe("Lundi 26 octobre");
    const region = screen.getByRole("region", { name: "Lundi 26 octobre" });
    expect(within(region).getAllByRole("link").map((l) => l.textContent)).toEqual(["09:00", "09:15"]);
  });

  it("heures rangées sous Matin, Après-midi, Soir ; moment vide absent (issue 130)", () => {
    const samedi = {
      cle: "2026-10-31",
      libelle: "Samedi 31 octobre",
      court: "sam.",
      numero: "31",
      heures: [
        { debut: "2026-10-31T10:30:00.000Z", libelle: "11:30" },
        { debut: "2026-10-31T13:00:00.000Z", libelle: "14:00" },
        { debut: "2026-10-31T13:15:00.000Z", libelle: "14:15" },
      ],
    };
    render(<ListeCreneaux jour={samedi} prestationId="p1" />);
    expect(screen.getAllByRole("heading", { level: 3 }).map((t) => t.textContent)).toEqual([
      "Matin",
      "Après-midi",
    ]);
    const apresMidi = screen.getByRole("list", { name: "Après-midi" });
    expect(within(apresMidi).getAllByRole("link").map((l) => l.textContent)).toEqual(["14:00", "14:15"]);
    expect(screen.queryByRole("heading", { name: "Soir" })).toBeNull();
  });

  it("chaque heure mène à la confirmation avec le coiffeur choisi", () => {
    render(<ListeCreneaux jour={mercredi} prestationId="p1" coiffeurId="c1" />);
    expect(screen.getByRole("link", { name: "10:00" }).getAttribute("href")).toBe(
      "/reserver/confirmation?prestation=p1&debut=2026-10-28T09%3A00%3A00.000Z&coiffeur=c1",
    );
  });

  it("zones tactiles de 48 px et chiffres à chasse fixe", () => {
    render(<ListeCreneaux jour={lundi} prestationId="p1" />);
    const classes = screen.getByRole("link", { name: "09:00" }).className;
    expect(classes).toContain("h-12");
    expect(classes).toContain("tabular-nums");
  });
});

describe("BandeJours", () => {
  it("un bouton par jour disponible, le jour choisi est pressé", () => {
    render(<BandeJours jours={[lundi, mardi, mercredi]} choisi="2026-10-28" onChoisir={() => {}} />);
    const boutons = screen.getAllByRole("button");
    expect(boutons.map((b) => b.getAttribute("aria-label"))).toEqual(["Lundi 26 octobre", "Mercredi 28 octobre"]);
    expect(boutons.map((b) => b.getAttribute("aria-pressed"))).toEqual(["false", "true"]);
  });

  it("jour sans créneau : affiché, inactif, non cliquable", () => {
    render(<BandeJours jours={[lundi, mardi, mercredi]} choisi="2026-10-26" onChoisir={() => {}} />);
    const sansCreneau = screen.getByLabelText("Mardi 27 octobre : aucun créneau");
    expect(sansCreneau.tagName).toBe("SPAN");
    expect(sansCreneau.className).toContain("bg-separateur");
    expect(sansCreneau.className).toContain("text-texte-secondaire");
  });

  it("cliquer un jour le choisit", () => {
    const onChoisir = vi.fn();
    render(<BandeJours jours={[lundi, mardi, mercredi]} choisi="2026-10-26" onChoisir={onChoisir} />);
    fireEvent.click(screen.getByRole("button", { name: "Mercredi 28 octobre" }));
    expect(onChoisir).toHaveBeenCalledWith("2026-10-28");
  });

  it("zones tactiles d'au moins 44 px (56 × 64)", () => {
    render(<BandeJours jours={[lundi]} choisi="2026-10-26" onChoisir={() => {}} />);
    const classes = screen.getByRole("button").className;
    expect(classes).toContain("h-16");
    expect(classes).toContain("w-14");
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
