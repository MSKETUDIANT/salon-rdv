import { BoutonLien } from "@/components/ui/bouton-lien";
import { lienSecondaire } from "@/components/ui/styles";
import { lienItineraire } from "@/lib/accueil";

// Sous la photo d'accueil, sur fond uni : titre court, adresse du salon et
// lien « Itinéraire » (issue 129), un seul bouton principal (charte §6), puis un
// simple lien vers « Mes réservations » (#7).
export function EnTeteSalon({ nom, adresse }: { nom: string; adresse: string | null }) {
  return (
    <div className="flex flex-col items-start gap-6 py-8">
      <div className="flex flex-col items-start gap-2">
        <h1 className="font-titre text-2xl font-medium break-words text-texte sm:text-3xl">
          {nom}
        </h1>
        {adresse && (
          <>
            <p className="flex items-start gap-2 text-base break-words text-texte-secondaire">
              <svg
                aria-hidden="true"
                viewBox="0 0 24 24"
                width="20"
                height="20"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                className="mt-0.5 shrink-0"
              >
                <path d="M12 21s-7-6.2-7-11.5a7 7 0 0 1 14 0C19 14.8 12 21 12 21Z" />
                <circle cx="12" cy="9.5" r="2.5" />
              </svg>
              <span>
                <span className="sr-only">Adresse : </span>
                {adresse}
              </span>
            </p>
            <a
              href={lienItineraire(adresse)}
              aria-label="Itinéraire vers le salon (Google Maps)"
              className={`${lienSecondaire} -mt-2 ml-7`}
            >
              Itinéraire
            </a>
          </>
        )}
      </div>
      <BoutonLien href="/reserver">Réserver</BoutonLien>
      <BoutonLien href="/mes-reservations" variante="secondaire">
        Mes réservations
      </BoutonLien>
    </div>
  );
}
