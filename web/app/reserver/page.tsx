import type { Metadata } from "next";
import { CartePrestation } from "@/components/reservation/carte-prestation";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { lireCatalogue } from "@/lib/lire-catalogue";
import { env } from "@/lib/env";

// Écran 1 du parcours : catalogue des prestations (BF-C2), sans connexion.
// Statique : catalogue en cache, revalidé chaque minute.
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Réserver · Salon RDV",
};

export default async function Reserver() {
  const { prestations } = await lireCatalogue(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col gap-6 px-4 py-8 sm:px-8">
      <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
        Choisissez une prestation
      </h1>
      {prestations.length === 0 ? (
        <div className="flex flex-col items-start gap-6">
          <p className="text-base text-texte">Aucune prestation n&apos;est proposée pour le moment.</p>
          <BoutonLien href="/" variante="secondaire">
            Retour à l&apos;accueil
          </BoutonLien>
        </div>
      ) : (
        <ul className="flex flex-col gap-3">
          {prestations.map((prestation) => (
            <li key={prestation.id}>
              <CartePrestation prestation={prestation} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
