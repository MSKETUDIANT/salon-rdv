import { describe, expect, it, vi } from "vitest";
import type { Catalogue } from "@/lib/catalogue";
import {
  codeValide,
  emailValide,
  envoyerCode,
  jourEtHeure,
  lienCreneaux,
  lireDemande,
  messageErreurAuth,
  reserver,
  validerCode,
} from "@/lib/reservation";

const catalogue: Catalogue = {
  fuseau: "Africa/Tunis",
  prestations: [{ id: "p1", nom: "Coupe femme", prix: 35, dureeMinutes: 45 }],
  coiffeurs: [
    { id: "a", nom: "Amira", prestations: ["p1"] },
    { id: "z", nom: "Zied", prestations: [] },
  ],
};
const debut = "2026-10-27T09:00:00.000Z";
const demande = { prestation: catalogue.prestations[0], debut };

describe("lireDemande", () => {
  it("prestation, heure et coiffeur compétent", () => {
    const params = new URLSearchParams({ prestation: "p1", debut, coiffeur: "a" });
    expect(lireDemande(params, catalogue)).toEqual({ ...demande, coiffeur: catalogue.coiffeurs[0] });
  });

  it("sans coiffeur : « Peu importe »", () => {
    expect(lireDemande(new URLSearchParams({ prestation: "p1", debut }), catalogue)).toEqual(demande);
  });

  it("lien invalide : prestation inconnue, heure illisible, coiffeur non compétent", () => {
    expect(lireDemande(new URLSearchParams({ prestation: "p9", debut }), catalogue)).toBeNull();
    expect(lireDemande(new URLSearchParams({ prestation: "p1", debut: "demain" }), catalogue)).toBeNull();
    expect(
      lireDemande(new URLSearchParams({ prestation: "p1", debut, coiffeur: "z" }), catalogue),
    ).toBeNull();
  });
});

describe("formats et liens", () => {
  it("jour et heure à l'heure du salon", () => {
    expect(jourEtHeure(debut, "Africa/Tunis")).toEqual({ jour: "Mardi 27 octobre", heure: "10:00" });
  });

  it("retour aux créneaux avec la prestation et le filtre coiffeur", () => {
    expect(lienCreneaux("p1", "a")).toBe("/reserver/creneaux?prestation=p1&coiffeur=a");
    expect(lienCreneaux("p1")).toBe("/reserver/creneaux?prestation=p1");
    expect(lienCreneaux("p1", "a", true)).toBe("/reserver/creneaux?prestation=p1&coiffeur=a&pris=1");
  });

  it("e-mail et code à 6 chiffres", () => {
    expect(emailValide("client@exemple.tn")).toBe(true);
    expect(emailValide("client@exemple")).toBe(false);
    expect(codeValide("123456")).toBe(true);
    expect(codeValide("12345")).toBe(false);
    expect(codeValide("12345a")).toBe(false);
  });

  it("messages d'erreur d'authentification", () => {
    expect(messageErreurAuth("otp_expired")).toContain("Code incorrect ou expiré");
    expect(messageErreurAuth("over_email_send_rate_limit")).toContain("Trop de demandes");
    expect(messageErreurAuth("autre")).toBe("Une erreur est survenue. Réessayez.");
  });
});

// Faux client Supabase : seules les méthodes appelées.
function client(reponses: { otp?: unknown; verify?: unknown; rpc?: unknown }) {
  return {
    auth: {
      signInWithOtp: vi.fn().mockResolvedValue(reponses.otp ?? { error: null }),
      verifyOtp: vi.fn().mockResolvedValue(reponses.verify ?? { error: null }),
    },
    rpc: vi.fn().mockResolvedValue(reponses.rpc ?? { data: [], error: null }),
  } as unknown as Parameters<typeof reserver>[0] & {
    auth: { signInWithOtp: ReturnType<typeof vi.fn>; verifyOtp: ReturnType<typeof vi.fn> };
    rpc: ReturnType<typeof vi.fn>;
  };
}

describe("connexion par code", () => {
  it("envoie le code, crée le compte si besoin, avec le nom", async () => {
    const supabase = client({});
    expect(await envoyerCode(supabase, "c@exemple.tn", "Salma")).toBeNull();
    expect(supabase.auth.signInWithOtp).toHaveBeenCalledWith({
      email: "c@exemple.tn",
      options: { shouldCreateUser: true, data: { nom: "Salma" } },
    });
  });

  it("sans nom : connexion à un compte existant seulement", async () => {
    const supabase = client({ otp: { error: { code: "otp_disabled" } } });
    expect(await envoyerCode(supabase, "c@exemple.tn", null)).toContain("Aucun compte");
    expect(supabase.auth.signInWithOtp).toHaveBeenCalledWith({
      email: "c@exemple.tn",
      options: { shouldCreateUser: false },
    });
  });

  it("valide le code de type e-mail ; code faux : message clair", async () => {
    const supabase = client({ verify: { error: { code: "otp_expired" } } });
    expect(await validerCode(supabase, "c@exemple.tn", "123456")).toContain("Code incorrect");
    expect(supabase.auth.verifyOtp).toHaveBeenCalledWith({
      email: "c@exemple.tn",
      token: "123456",
      type: "email",
    });
  });
});

describe("reserver", () => {
  it("appelle la fonction SQL ; confirmée avec le coiffeur attribué", async () => {
    const supabase = client({ rpc: { data: [{ id: "r1", coiffeur_id: "a" }], error: null } });
    expect(await reserver(supabase, demande)).toEqual({ statut: "confirmee", coiffeurId: "a" });
    expect(supabase.rpc).toHaveBeenCalledWith("reserver", {
      p_prestation: "p1",
      p_debut: debut,
      p_coiffeur: undefined,
    });
  });

  it("PT409 : pris ; PT401 : déconnecté ; 55P03 : occupé, à réessayer ; autre : erreur", async () => {
    expect(await reserver(client({ rpc: { data: null, error: { code: "PT409" } } }), demande)).toEqual({
      statut: "pris",
    });
    expect(await reserver(client({ rpc: { data: null, error: { code: "PT401" } } }), demande)).toEqual({
      statut: "deconnecte",
    });
    expect(await reserver(client({ rpc: { data: null, error: { code: "55P03" } } }), demande)).toEqual({
      statut: "occupe",
    });
    expect(await reserver(client({ rpc: { data: null, error: { code: "500" } } }), demande)).toEqual({
      statut: "erreur",
    });
  });
});
