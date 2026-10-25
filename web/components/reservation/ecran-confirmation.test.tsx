// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from "vitest";
import { EcranConfirmation } from "@/components/reservation/ecran-confirmation";
import type { Catalogue } from "@/lib/catalogue";

const etat = vi.hoisted(() => ({ recherche: "", replace: null as unknown as Mock<(url: string) => void> }));
vi.mock("next/navigation", () => ({
  useSearchParams: () => new URLSearchParams(etat.recherche),
  useRouter: () => ({ replace: (url: string) => etat.replace(url) }),
}));

// Faux client Supabase : session, code e-mail et fonction reserver.
const faux = vi.hoisted(() => ({
  session: null as null | { user: { email: string } },
  ecouteur: null as null | ((evenement: string, session: unknown) => void),
  signInWithOtp: null as unknown as Mock<(...args: unknown[]) => Promise<unknown>>,
  verifyOtp: null as unknown as Mock<(...args: unknown[]) => Promise<unknown>>,
  rpc: null as unknown as Mock<(...args: unknown[]) => Promise<unknown>>,
}));
vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: {
      getSession: () => Promise.resolve({ data: { session: faux.session } }),
      onAuthStateChange: (ecouteur: (evenement: string, session: unknown) => void) => {
        faux.ecouteur = ecouteur;
        return { data: { subscription: { unsubscribe: () => {} } } };
      },
      signInWithOtp: (...args: unknown[]) => faux.signInWithOtp(...args),
      verifyOtp: (...args: unknown[]) => faux.verifyOtp(...args),
      signOut: () => Promise.resolve({ error: null }),
    },
    rpc: (...args: unknown[]) => faux.rpc(...args),
  }),
}));

const catalogue: Catalogue = {
  fuseau: "Africa/Tunis",
  prestations: [{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }],
  coiffeurs: [
    { id: "a", nom: "Amira", prestations: ["p1"] },
    { id: "y", nom: "Youssef", prestations: ["p1"] },
  ],
};
const debut = "2026-10-27T09:00:00.000Z";

beforeEach(() => {
  etat.recherche = new URLSearchParams({ prestation: "p1", debut }).toString();
  etat.replace = vi.fn();
  faux.session = null;
  faux.signInWithOtp = vi.fn().mockResolvedValue({ error: null });
  faux.verifyOtp = vi.fn().mockImplementation(() => {
    faux.ecouteur?.("SIGNED_IN", { user: { email: "salma@exemple.tn" } });
    return Promise.resolve({ error: null });
  });
  faux.rpc = vi.fn().mockResolvedValue({ data: [{ id: "r1", coiffeur_id: "y" }], error: null });
});

afterEach(cleanup);

function saisir(libelle: string, valeur: string) {
  fireEvent.change(screen.getByLabelText(libelle), { target: { value: valeur } });
}

async function seConnecter() {
  await screen.findByText(/Recevez un code/);
  saisir("Nom", "Salma Ben Ali");
  saisir("E-mail", "salma@exemple.tn");
  await act(async () => fireEvent.click(screen.getByRole("button", { name: "Recevoir le code" })));
  saisir("Code à 6 chiffres", "123456");
  await act(async () => fireEvent.click(screen.getByRole("button", { name: "Valider le code" })));
}

describe("EcranConfirmation", () => {
  it("récapitulatif : prestation, « Peu importe », date, heure, durée, prix", async () => {
    render(<EcranConfirmation catalogue={catalogue} />);
    await screen.findByText(/Recevez un code/);
    const recap = document.querySelector("dl")!;
    expect(recap.textContent?.replace(/\s/g, " ")).toBe(
      "PrestationCoupe femmeCoiffeurPeu importe (attribué à la confirmation)DateMardi 27 octobreHeure10:00Durée45 minPrix35 DT",
    );
  });

  it("« Confirmer » sans connexion : jamais désactivé, indique ce qui manque", async () => {
    render(<EcranConfirmation catalogue={catalogue} />);
    await screen.findByText(/Recevez un code/);
    const bouton = screen.getByRole("button", { name: "Confirmer la réservation" });
    expect(bouton.hasAttribute("disabled")).toBe(false);

    await act(async () => fireEvent.click(bouton));
    expect(screen.getByRole("alert").textContent).toContain("indiquez votre nom et votre e-mail");
    expect(faux.rpc).not.toHaveBeenCalled();
  });

  it("e-mail : champs vides signalés, code demandé avec le nom", async () => {
    render(<EcranConfirmation catalogue={catalogue} />);
    await screen.findByText(/Recevez un code/);
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Recevoir le code" })));
    expect(screen.getByText("Indiquez votre nom.")).toBeTruthy();
    expect(screen.getByText("Indiquez une adresse e-mail valide.")).toBeTruthy();
    expect(faux.signInWithOtp).not.toHaveBeenCalled();

    saisir("Nom", "Salma Ben Ali");
    saisir("E-mail", "salma@exemple.tn");
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Recevoir le code" })));
    expect(faux.signInWithOtp).toHaveBeenCalledWith({
      email: "salma@exemple.tn",
      options: { shouldCreateUser: true, data: { nom: "Salma Ben Ali" } },
    });

    const champCode = screen.getByLabelText("Code à 6 chiffres");
    expect(champCode.getAttribute("inputmode")).toBe("numeric");
    expect(champCode.getAttribute("autocomplete")).toBe("one-time-code");
  });

  it("connexion sans quitter l'écran, créneau conservé, puis réservation confirmée", async () => {
    render(<EcranConfirmation catalogue={catalogue} />);
    await seConnecter();
    expect(screen.getByText("salma@exemple.tn")).toBeTruthy();
    expect(screen.getByText("Mardi 27 octobre")).toBeTruthy();

    await act(async () =>
      fireEvent.click(screen.getByRole("button", { name: "Confirmer la réservation" })),
    );
    expect(faux.rpc).toHaveBeenCalledWith("reserver", {
      p_prestation: "p1",
      p_debut: debut,
      p_coiffeur: undefined,
    });
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Réservation confirmée");
    expect(screen.getByText("Youssef")).toBeTruthy();
  });

  it("créneau pris entretemps : message, retour automatique aux créneaux (prestation, coiffeur, pris)", async () => {
    etat.recherche = new URLSearchParams({ prestation: "p1", debut, coiffeur: "a" }).toString();
    faux.session = { user: { email: "salma@exemple.tn" } };
    faux.rpc = vi.fn().mockResolvedValue({ data: null, error: { code: "PT409" } });
    render(<EcranConfirmation catalogue={catalogue} />);
    await screen.findByText("salma@exemple.tn");

    await act(async () =>
      fireEvent.click(screen.getByRole("button", { name: "Confirmer la réservation" })),
    );
    expect(screen.getByRole("alert").textContent).toContain("Ce créneau vient d'être pris. Retour aux créneaux");
    // Retour automatique (#51), sans entrée d'historique vers le créneau perdu.
    expect(etat.replace).toHaveBeenCalledWith("/reserver/creneaux?prestation=p1&coiffeur=a&pris=1");
    expect(screen.getByRole("link", { name: "Choisir un autre créneau" }).getAttribute("href")).toBe(
      "/reserver/creneaux?prestation=p1&coiffeur=a&pris=1",
    );
    expect(screen.queryByRole("button", { name: "Confirmer la réservation" })).toBeNull();
  });

  it("réservation confirmée : pas de retour automatique", async () => {
    faux.session = { user: { email: "salma@exemple.tn" } };
    render(<EcranConfirmation catalogue={catalogue} />);
    await screen.findByText("salma@exemple.tn");
    await act(async () =>
      fireEvent.click(screen.getByRole("button", { name: "Confirmer la réservation" })),
    );
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Réservation confirmée");
    expect(etat.replace).not.toHaveBeenCalled();
  });

  it("lien invalide : créneau introuvable", () => {
    etat.recherche = "prestation=p9";
    render(<EcranConfirmation catalogue={catalogue} />);
    expect(screen.getByRole("heading", { level: 1 }).textContent).toBe("Créneau introuvable");
  });
});
