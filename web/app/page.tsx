import { EnTeteSalon } from "@/components/en-tete-salon";
import { titreAccueil } from "@/lib/accueil";
import { env } from "@/lib/env";
import { lireSalon } from "@/lib/salon";

// Page publique : doit rester statique (nom du salon en cache, revalidé chaque
// minute). Le build échoue si elle devient dynamique.
export const ensureStatic = "navigation";

export default async function Accueil() {
  const salon = await lireSalon(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col justify-center px-4 py-12 sm:px-8">
      <EnTeteSalon nom={titreAccueil(salon)} />
    </main>
  );
}
