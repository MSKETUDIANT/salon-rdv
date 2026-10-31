import { describe, expect, it, vi } from "vitest";
import { seDeconnecter, suivreCompte } from "@/lib/compte";

// Client Supabase réduit à ce que lib/compte.ts utilise.
function client(email: string | null) {
  let ecouteur: ((evenement: string, session: unknown) => void) | undefined;
  const desabonner = vi.fn();
  const auth = {
    getSession: vi.fn(() =>
      Promise.resolve({ data: { session: email ? { user: { email } } : null } }),
    ),
    onAuthStateChange: vi.fn((rappel: (evenement: string, session: unknown) => void) => {
      ecouteur = rappel;
      return { data: { subscription: { unsubscribe: desabonner } } };
    }),
    signOut: vi.fn(() => Promise.resolve({ error: null })),
  };
  return {
    supabase: { auth } as never,
    auth,
    desabonner,
    changer: (session: unknown) => ecouteur?.("SIGNED_IN", session),
  };
}

describe("suivreCompte", () => {
  it("session actuelle, puis chaque changement ; arrêt du suivi", async () => {
    const { supabase, desabonner, changer } = client("cl@salon.test");
    const rappel = vi.fn();
    const arreter = suivreCompte(supabase, rappel);
    await vi.waitFor(() => expect(rappel).toHaveBeenCalledWith("cl@salon.test"));

    changer(null);
    expect(rappel).toHaveBeenLastCalledWith(null);
    changer({ user: { email: "autre@salon.test" } });
    expect(rappel).toHaveBeenLastCalledWith("autre@salon.test");

    arreter();
    expect(desabonner).toHaveBeenCalledTimes(1);
  });

  it("pas connecté : null", async () => {
    const { supabase } = client(null);
    const rappel = vi.fn();
    suivreCompte(supabase, rappel);
    await vi.waitFor(() => expect(rappel).toHaveBeenCalledWith(null));
  });
});

describe("seDeconnecter", () => {
  it("termine la session Supabase", async () => {
    const { supabase, auth } = client("cl@salon.test");
    await seDeconnecter(supabase);
    expect(auth.signOut).toHaveBeenCalledTimes(1);
  });
});
