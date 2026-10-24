import type { Metadata } from "next";
import { Suspense } from "react";
import { EcranConfirmation } from "@/components/reservation/ecran-confirmation";
import { env } from "@/lib/env";
import { lireCatalogue } from "@/lib/lire-catalogue";

// Écran 3 du parcours : récapitulatif, connexion par code e-mail et
// confirmation (BF-C4, BF-C5). La demande est dans l'URL, lue côté
// navigateur : la page reste statique.
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Confirmer · Salon RDV",
};

export default async function Confirmation() {
  const catalogue = await lireCatalogue(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 py-8 sm:px-8">
      <Suspense fallback={<p className="text-base text-texte-secondaire">Chargement…</p>}>
        <EcranConfirmation catalogue={catalogue} />
      </Suspense>
    </main>
  );
}
