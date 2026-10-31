// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi, type Mock } from "vitest";
import { EcranMesReservations } from "@/components/mes-reservations/ecran-mes-reservations";

// Faux client Supabase : session, code e-mail, mes_reservations et
// annuler_reservation.
const faux = vi.hoisted(() => ({
  session: null as null | { user: { email: string } },
  signInWithOtp: null as unknown as Mock<(...args: unknown[]) => Promise<unknown>>,
  rpc: null as unknown as Mock<(nom: string, args: unknown) => Promise<unknown>>,
}));
vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    auth: {
      getSession: () => Promise.resolve({ data: { session: faux.session } }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      signInWithOtp: (...args: unknown[]) => faux.signInWithOtp(...args),
      verifyOtp: () => Promise.resolve({ error: null }),
      signOut: () => Promise.resolve({ error: null }),
    },
    rpc: (nom: string, args: unknown) => faux.rpc(nom, args),
  }),
}));

function ligne(id: string, debut: string, statut: string, annulable: boolean, prestation = "Coupe femme") {
  return {
    id,
    prestation,
    prix: 35,
    duree_minutes: 45,
    coiffeur: "Amira",
    debut,
    fin: debut,
    statut,
    annulable,
  };
}

let lignes: ReturnType<typeof ligne>[];
let reponseAnnulation: unknown;

beforeEach(() => {
  faux.session = { user: { email: "salma@exemple.tn" } };
  faux.signInWithOtp = vi.fn().mockResolvedValue({ error: null });
  lignes = [
    ligne("r-passee", "2020-01-07T09:00:00Z", "terminee", false, "Brushing"),
    ligne("r1", "2030-01-08T09:00:00Z", "confirmee", true),
    ligne("r-annulee", "2030-01-09T09:00:00Z", "annulee", false, "Couleur"),
  ];
  reponseAnnulation = { data: [{ id: "r1", statut: "annulee" }], error: null };
  faux.rpc = vi.fn().mockImplementation((nom: string) => {
    if (nom === "mes_reservations") return Promise.resolve({ data: lignes, error: null });
    lignes = lignes.map((l) => (l.id === "r1" ? { ...l, statut: "annulee", annulable: false } : l));
    return Promise.resolve(reponseAnnulation);
  });
});

afterEach(cleanup);

function section(nom: string) {
  return screen.getByRole("region", { name: nom });
}

describe("EcranMesReservations", () => {
  it("non connecté : e-mail seul, connexion à un compte existant", async () => {
    faux.session = null;
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" />);
    await screen.findByText(/l'e-mail utilisé pour réserver/);
    expect(screen.queryByLabelText("Nom")).toBeNull();
    fireEvent.change(screen.getByLabelText("E-mail"), { target: { value: "salma@exemple.tn" } });
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Recevoir le code" })));
    expect(faux.signInWithOtp).toHaveBeenCalledWith({
      email: "salma@exemple.tn",
      options: { shouldCreateUser: false },
    });
    expect(screen.getByLabelText("Code à 6 chiffres")).toBeTruthy();
    expect(faux.rpc).not.toHaveBeenCalled();
  });

  it("connecté : à venir, puis passées et annulées, avec le détail", async () => {
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" />);
    await screen.findByRole("region", { name: "À venir" });
    expect(faux.rpc).toHaveBeenCalledWith("mes_reservations", { p_salon: "s1" });

    const aVenir = section("À venir");
    expect(within(aVenir).getByRole("heading", { name: "Coupe femme" })).toBeTruthy();
    expect(aVenir.querySelector("dl")!.textContent?.replace(/\s/g, " ")).toBe(
      "CoiffeurAmiraDateMardi 8 janvierHeure10:00Durée45 minPrix35 DTStatutConfirmée",
    );

    const historique = section("Passées et annulées");
    expect(within(historique).getAllByRole("heading", { level: 3 }).map((h) => h.textContent)).toEqual([
      "Couleur",
      "Brushing",
    ]);
    expect(within(historique).getByText("Annulée")).toBeTruthy();
    expect(within(historique).getByText("Terminée")).toBeTruthy();
    expect(within(historique).queryByRole("button", { name: "Annuler la réservation" })).toBeNull();
  });

  it("annuler : confirmation demandée, puis la réservation passe dans l'historique", async () => {
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" />);
    await screen.findByRole("region", { name: "À venir" });

    fireEvent.click(screen.getByRole("button", { name: "Annuler la réservation" }));
    expect(faux.rpc).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByRole("button", { name: "Non, garder" }));
    fireEvent.click(screen.getByRole("button", { name: "Annuler la réservation" }));
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Oui, annuler" })));

    expect(faux.rpc).toHaveBeenCalledWith("annuler_reservation", { p_reservation: "r1" });
    expect(screen.getByRole("status").textContent).toBe("Réservation du mardi 8 janvier à 10:00 annulée.");
    expect(within(section("À venir")).getByText("Aucune réservation à venir.")).toBeTruthy();
    expect(within(section("Passées et annulées")).getAllByText("Annulée")).toHaveLength(2);
  });

  it("plus annulable entre-temps : message clair", async () => {
    reponseAnnulation = { data: null, error: { code: "PT409" } };
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" />);
    await screen.findByRole("region", { name: "À venir" });
    fireEvent.click(screen.getByRole("button", { name: "Annuler la réservation" }));
    await act(async () => fireEvent.click(screen.getByRole("button", { name: "Oui, annuler" })));
    expect(screen.getByRole("alert").textContent).toBe("Cette réservation ne peut plus être annulée.");
  });

  it("délai d'annulation passé (issue 118) : message à la place de « Annuler »", async () => {
    lignes = [ligne("r1", "2030-01-08T09:00:00Z", "confirmee", false)];
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" delaiAnnulation={120} />);
    const aVenir = await screen.findByRole("region", { name: "À venir" });
    expect(
      within(aVenir).getByText(
        "Annulation possible jusqu'à 2 h avant le rendez-vous. Contactez le salon.",
      ),
    ).toBeTruthy();
    expect(within(aVenir).queryByRole("button", { name: "Annuler la réservation" })).toBeNull();
    // Sans numéro du salon : pas de lien d'appel.
    expect(within(aVenir).queryByRole("link", { name: /Appeler le salon/ })).toBeNull();
  });

  it("délai passé et numéro du salon (issue 129) : lien pour appeler", async () => {
    lignes = [ligne("r1", "2030-01-08T09:00:00Z", "confirmee", false)];
    render(
      <EcranMesReservations
        salonId="s1"
        fuseau="Africa/Tunis"
        delaiAnnulation={120}
        telephone="71 234 567"
      />,
    );
    const aVenir = await screen.findByRole("region", { name: "À venir" });
    const lien = within(aVenir).getByRole("link", { name: "Appeler le salon au 71 234 567" });
    expect(lien.getAttribute("href")).toBe("tel:71234567");
  });

  it("annulable malgré un délai réglé : bouton, pas de message", async () => {
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" delaiAnnulation={120} />);
    const aVenir = await screen.findByRole("region", { name: "À venir" });
    expect(within(aVenir).getByRole("button", { name: "Annuler la réservation" })).toBeTruthy();
    expect(within(aVenir).queryByText(/Contactez le salon/)).toBeNull();
  });

  it("aucune réservation : invitation à réserver", async () => {
    lignes = [];
    render(<EcranMesReservations salonId="s1" fuseau="Africa/Tunis" />);
    await screen.findByText("Aucune réservation à venir.");
    expect(screen.getByRole("link", { name: "Réserver" }).getAttribute("href")).toBe("/reserver");
    expect(screen.queryByRole("region", { name: "Passées et annulées" })).toBeNull();
  });
});
