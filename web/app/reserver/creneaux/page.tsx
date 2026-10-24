import type { Metadata } from "next";
import { Suspense } from "react";
import { EcranCreneaux } from "@/components/reservation/ecran-creneaux";
import { lireCatalogue } from "@/lib/lire-catalogue";
import { env } from "@/lib/env";

// Écran 2 du parcours : créneaux libres (BF-C1, BF-C3). La prestation est dans
// l'URL (?prestation=) et lue côté navigateur : la page reste statique, même
// pour une prestation créée après le build.
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Choisir un créneau · Salon RDV",
};

export default async function Creneaux() {
  const catalogue = await lireCatalogue(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 py-8 sm:px-8">
      <Suspense
        fallback={<p className="text-base text-texte-secondaire">Chargement des créneaux…</p>}
      >
        <EcranCreneaux catalogue={catalogue} />
      </Suspense>
    </main>
  );
}
