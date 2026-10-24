import type { Metadata } from "next";
import { Suspense } from "react";
import { EcranCreneaux } from "@/components/reservation/ecran-creneaux";
import { JOURS_AFFICHES } from "@/lib/creneaux";
import { env } from "@/lib/env";
import { lireCatalogue } from "@/lib/lire-catalogue";
import { scriptPrechargement } from "@/lib/precharger-creneaux";

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
      {/* Lance la lecture des créneaux dès la réception du HTML (BNF-5). */}
      <script
        dangerouslySetInnerHTML={{
          __html: scriptPrechargement(catalogue.fuseau, JOURS_AFFICHES, env.supabaseAnonKey),
        }}
      />
      <Suspense
        fallback={<p className="text-base text-texte-secondaire">Chargement des créneaux…</p>}
      >
        <EcranCreneaux catalogue={catalogue} />
      </Suspense>
    </main>
  );
}
