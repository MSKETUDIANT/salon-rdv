import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "@/lib/database.types";
import { env } from "@/lib/env";

// Client lié à la session de l'utilisateur (cookies), pour les futures pages
// authentifiées. Rend la page dynamique : ne pas l'utiliser sur une page publique.
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(env.supabaseUrl, env.supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Appelé depuis un Server Component : les cookies y sont en lecture
          // seule. Le rafraîchissement de session se fera dans le proxy (issue
          // connexion).
        }
      },
    },
  });
}
