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
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 pt-4 sm:px-8 sm:pt-8">
      {/* Emplacement de la photo du salon (4:3), jamais de texte dessus.
          Photo à choisir par Sparta (charte §6). */}
      <div aria-hidden="true" className="aspect-4/3 w-full rounded-base bg-separateur" />
      <EnTeteSalon nom={titreAccueil(salon)} />
    </main>
  );
}
