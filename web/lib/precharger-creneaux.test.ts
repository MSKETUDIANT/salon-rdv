// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { lireCreneaux, periode } from "@/lib/creneaux";
import { prendrePrechargement, scriptPrechargement } from "@/lib/precharger-creneaux";

const TUNIS = "Africa/Tunis";

beforeEach(() => {
  vi.useFakeTimers({ toFake: ["Date"] });
  vi.setSystemTime(new Date("2026-10-26T10:00:00Z"));
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "cle-anon");
});

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
  vi.unstubAllGlobals();
  window.history.replaceState({}, "", "/");
});

// Exécute le script tel qu'il est inclus dans la page.
function executerScript() {
  new Function(scriptPrechargement(TUNIS, 14, "cle-anon"))();
}

describe("scriptPrechargement", () => {
  it("lance la même requête que lireCreneaux, dès son exécution", async () => {
    window.history.replaceState({}, "", "/reserver/creneaux?prestation=p1");
    const fetch = vi.fn().mockImplementation(() => Promise.resolve(new Response("[]")));
    vi.stubGlobal("fetch", fetch);

    executerScript();
    await lireCreneaux({ prestationId: "p1", ...periode(new Date(), TUNIS) });

    expect(fetch).toHaveBeenCalledTimes(2);
    expect(fetch.mock.calls[0][0]).toBe(fetch.mock.calls[1][0]);
    expect(fetch.mock.calls[0][0]).toBe("/api/creneaux?p_prestation=p1&p_du=2026-10-26&p_au=2026-11-08");
    expect(fetch.mock.calls[0][1]).toEqual({ headers: { apikey: "cle-anon" } });
  });

  it("sans prestation dans l'URL : aucune requête", () => {
    window.history.replaceState({}, "", "/reserver/creneaux");
    const fetch = vi.fn();
    vi.stubGlobal("fetch", fetch);

    executerScript();
    expect(fetch).not.toHaveBeenCalled();
  });
});

describe("prendrePrechargement", () => {
  it("rend la lecture anticipée si elle correspond, une seule fois", async () => {
    window.history.replaceState({}, "", "/reserver/creneaux?prestation=p1");
    const creneaux = [{ coiffeur_id: "a", debut: "2026-10-26T09:00:00+00:00", fin: "2026-10-26T09:30:00+00:00" }];
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(JSON.stringify(creneaux))));
    executerScript();

    const demande = { prestationId: "p1", du: "2026-10-26", au: "2026-11-08" };
    await expect(prendrePrechargement(demande)).resolves.toEqual(creneaux);
    expect(prendrePrechargement(demande)).toBeUndefined();
  });

  it("autre prestation ou autre période : rien", () => {
    window.history.replaceState({}, "", "/reserver/creneaux?prestation=p1");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("[]")));

    executerScript();
    expect(prendrePrechargement({ prestationId: "p2", du: "2026-10-26", au: "2026-11-08" })).toBeUndefined();
    executerScript();
    expect(prendrePrechargement({ prestationId: "p1", du: "2026-10-27", au: "2026-11-09" })).toBeUndefined();
  });

  it("erreur HTTP : la lecture reprise échoue, l'écran affichera l'erreur", async () => {
    window.history.replaceState({}, "", "/reserver/creneaux?prestation=p1");
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response("{}", { status: 500 })));

    executerScript();
    await expect(
      prendrePrechargement({ prestationId: "p1", du: "2026-10-26", au: "2026-11-08" }),
    ).rejects.toThrow("HTTP 500");
  });
});
