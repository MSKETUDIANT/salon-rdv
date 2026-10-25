import Link from "next/link";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { focus } from "@/components/ui/styles";

// Sous la photo d'accueil, sur fond uni : titre court et un seul bouton
// (charte §6), puis un simple lien vers « Mes réservations » (#7).
export function EnTeteSalon({ nom }: { nom: string }) {
  return (
    <div className="flex flex-col items-start gap-6 py-8">
      <h1 className="font-titre text-2xl font-medium break-words text-texte sm:text-3xl">
        {nom}
      </h1>
      <BoutonLien href="/reserver">Réserver</BoutonLien>
      <Link
        href="/mes-reservations"
        className={`inline-flex min-h-11 items-center rounded-base text-base font-semibold text-accent underline ${focus}`}
      >
        Mes réservations
      </Link>
    </div>
  );
}
