import { EnTeteSalon } from "@/components/en-tete-salon";
import { PhotoAccueil } from "@/components/photo-accueil";
import { titreAccueil } from "@/lib/accueil";
import { env } from "@/lib/env";
import { lireSalon } from "@/lib/salon";

// Page publique : doit rester statique (nom et photo du salon en cache,
// revalidés chaque minute). Le build échoue si elle devient dynamique.
export const ensureStatic = "navigation";

export default async function Accueil() {
  const salon = await lireSalon(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 pt-4 sm:px-8 sm:pt-8">
      <PhotoAccueil photo={salon?.photo ?? null} nom={titreAccueil(salon)} />
      <EnTeteSalon nom={titreAccueil(salon)} />
    </main>
  );
}
