import type { Metadata } from "next";
import { BoutonLien } from "@/components/ui/bouton-lien";

// Page d'attente, remplacée par l'écran 3 du parcours (connexion et
// confirmation, #6).
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Confirmer · Salon RDV",
};

export default function Confirmation() {
  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col items-start justify-center gap-6 px-4 py-12 sm:px-8">
      <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
        La confirmation en ligne arrive bientôt
      </h1>
      <BoutonLien href="/reserver" variante="secondaire">
        Retour aux prestations
      </BoutonLien>
    </main>
  );
}
