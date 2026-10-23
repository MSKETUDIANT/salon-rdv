import { BoutonLien } from "@/components/ui/bouton-lien";

// Sous la photo d'accueil, sur fond uni : titre court et un seul bouton
// (charte §6).
export function EnTeteSalon({ nom }: { nom: string }) {
  return (
    <div className="flex flex-col items-start gap-6 py-8">
      <h1 className="font-titre text-2xl font-medium break-words text-texte sm:text-3xl">
        {nom}
      </h1>
      <BoutonLien href="/reserver">Réserver</BoutonLien>
    </div>
  );
}
