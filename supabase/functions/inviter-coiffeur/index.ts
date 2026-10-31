// Issue #148 : invitation d'un coiffeur avec envoi de l'e-mail (logique.ts).
import { traiter } from "./logique.ts";

// Clé secrète : l'ancienne service_role, sinon la nouvelle clé secrète
// (SUPABASE_SECRET_KEYS, objet JSON dont la clé « default »).
function cleSecrete(): string {
  const ancienne = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (ancienne) return ancienne;
  const nouvelles = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  return nouvelles.default ?? "";
}

Deno.serve((requete) =>
  traiter(requete, {
    url: Deno.env.get("SUPABASE_URL") ?? "",
    cleSecrete: cleSecrete(),
    fetch,
  })
);
