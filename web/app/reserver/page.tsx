import type { Metadata } from "next";
import { BoutonLien } from "@/components/ui/bouton-lien";

// Page d'attente, remplacée par le parcours de réservation (#5).
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Réserver · Salon RDV",
};

export default function Reserver() {
  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col items-start justify-center gap-6 px-4 py-12 sm:px-8">
      <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
        La réservation en ligne arrive bientôt
      </h1>
      <BoutonLien href="/" variante="secondaire">
        Retour à l&apos;accueil
      </BoutonLien>
    </main>
  );
}
