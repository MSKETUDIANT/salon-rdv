import Image from "next/image";
import { EnTeteSalon } from "@/components/en-tete-salon";
import { titreAccueil } from "@/lib/accueil";
import { env } from "@/lib/env";
import { lireSalon } from "@/lib/salon";
import photoSalon from "@/public/accueil-salon.webp";

// Page publique : doit rester statique (nom du salon en cache, revalidé chaque
// minute). Le build échoue si elle devient dynamique.
export const ensureStatic = "navigation";

export default async function Accueil() {
  const salon = await lireSalon(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 pt-4 sm:px-8 sm:pt-8">
      {/* Photo de démonstration, déjà recadrée en 4:3 (1600 × 1200, source dans
          docs/charte-graphique.md §6). Jamais de texte dessus. */}
      <Image
        src={photoSalon}
        alt="Fauteuil de coiffure devant un meuble en bois et un miroir rond"
        sizes="(min-width: 42rem) 608px, calc(100vw - 2rem)"
        preload
        className="aspect-4/3 h-auto w-full rounded-base object-cover"
      />
      <EnTeteSalon nom={titreAccueil(salon)} />
    </main>
  );
}
