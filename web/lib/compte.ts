import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";

// Compte connecté sur le site (#119, règle 3 de docs/architecture.md) : seule
// cette couche lit la session Supabase ou s'en déconnecte ; les composants
// passent par ces fonctions.

type Client = SupabaseClient<Database>;

// Suit l'e-mail du compte connecté (null : pas connecté) : session actuelle,
// puis chaque changement. Renvoie de quoi arrêter le suivi.
export function suivreCompte(supabase: Client, rappel: (email: string | null) => void): () => void {
  supabase.auth.getSession().then(({ data }) => rappel(data.session?.user.email ?? null));
  const { data } = supabase.auth.onAuthStateChange((_evenement, session) =>
    rappel(session?.user.email ?? null),
  );
  return () => data.subscription.unsubscribe();
}

// « Changer de compte » : fin de la session sur cet appareil.
export async function seDeconnecter(supabase: Client): Promise<void> {
  await supabase.auth.signOut();
}
