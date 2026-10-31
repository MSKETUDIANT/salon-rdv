import { Carte } from "@/components/ui/carte";

// Écran 3 en cours de chargement (issue 131) : la forme de la page plutôt
// qu'un « Chargement… » seul. Les textes connus d'avance restent réels (titre,
// intitulés du récapitulatif, « Vos coordonnées ») ; les valeurs encore
// inconnues sont des barres `separateur`, aux mêmes hauteurs que le contenu :
// rien ne saute à son arrivée. Lu « Chargement de la réservation… » par les
// lecteurs d'écran ; pulsation coupée si l'utilisateur demande moins
// d'animations.
const barre = "rounded-base bg-separateur motion-safe:animate-pulse";

export function SqueletteConfirmation() {
  return (
    <div role="status" className="flex flex-col gap-6">
      <span className="sr-only">Chargement de la réservation…</span>

      {/* « ‹ Retour » : même hauteur que le lien (44 px). */}
      <div aria-hidden="true" className="flex min-h-11 items-center">
        <span className={`${barre} h-5 w-20`} />
      </div>

      <p aria-hidden="true" className="font-titre text-2xl font-medium text-texte sm:text-3xl">
        Confirmer la réservation
      </p>

      <Carte aria-hidden="true" className="w-full">
        <div className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2">
          {["Prestation", "Coiffeur", "Date", "Heure", "Durée", "Prix"].map((terme, i) => (
            <div key={terme} className="contents">
              <span className="text-base text-texte-secondaire">{terme}</span>
              {terme === "Coiffeur" ? (
                // « Peu importe (attribué à la confirmation) », le choix par
                // défaut, tient sur deux lignes à 360 px, sur une au-delà.
                <span className="flex h-12 flex-col justify-around sm:h-6 sm:justify-center">
                  <span className={`${barre} h-4 w-40`} />
                  <span className={`${barre} h-4 w-24 sm:hidden`} />
                </span>
              ) : (
                <span className="flex h-6 items-center">
                  <span className={`${barre} h-4 ${i % 2 ? "w-24" : "w-36"}`} />
                </span>
              )}
            </div>
          ))}
        </div>
      </Carte>

      <div aria-hidden="true" className="flex flex-col gap-4">
        <p className="font-titre text-xl font-medium text-texte">Vos coordonnées</p>
        {/* Introduction : deux lignes de texte à 360 px, une au-delà. */}
        <div className="flex flex-col">
          <span className="flex h-6 items-center">
            <span className={`${barre} h-4 w-full`} />
          </span>
          <span className="flex h-6 items-center sm:hidden">
            <span className={`${barre} h-4 w-2/3`} />
          </span>
        </div>
        {[0, 1].map((champ) => (
          <div key={champ} className="flex flex-col gap-2">
            <span className="flex h-6 items-center">
              <span className={`${barre} h-4 w-16`} />
            </span>
            <span className="h-12 w-full rounded-base border border-separateur bg-surface" />
          </div>
        ))}
        {/* « Recevoir le code ». */}
        <span className="h-12 w-40 rounded-base border border-separateur bg-surface" />
      </div>

      {/* « Confirmer la réservation ». */}

      <span aria-hidden="true" className={`${barre} h-12 w-56`} />
    </div>
  );
}
