"use client";

import { useEffect, useRef } from "react";
import { focus } from "@/components/ui/styles";
import { moisDeLaBande, repereMois, type Jour } from "@/lib/creneaux";

// Écran 2 : bande horizontale des jours de la période, défilable dans sa
// largeur (la page, elle, ne défile pas horizontalement). Un jour sans créneau
// est un élément inactif, non cliquable : `texte-secondaire` sur `separateur`
// (charte §2). Le jour choisi reste visible dans la bande. Au-dessus, le ou les
// mois de la bande ; devant le 1er d'un nouveau mois, un repère « nov. » (#55),
// décoratif : chaque jour annonce déjà son mois aux lecteurs d'écran.
export function BandeJours({
  jours,
  choisi,
  onChoisir,
}: {
  jours: Jour[];
  choisi: string;
  onChoisir: (cle: string) => void;
}) {
  const refChoisi = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    refChoisi.current?.scrollIntoView?.({ block: "nearest", inline: "nearest" });
  }, [choisi]);

  return (
    <div className="flex flex-col gap-2">
      <p className="text-lg font-semibold text-texte">{moisDeLaBande(jours)}</p>
      <div
        role="group"
        aria-label="Jour"
        className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0"
      >
        <ul className="flex gap-2 py-1">
          {jours.map((jour, index) => {
            const repere = repereMois(jours, index);
            const contenu = (
              <>
                <span className="text-base">{jour.court}</span>
                <span className="text-lg font-semibold">{jour.numero}</span>
              </>
            );
            const forme =
              "flex h-16 w-14 flex-col items-center justify-center rounded-base border tabular-nums";

            return (
              <li key={jour.cle} className="flex shrink-0 gap-2">
                {repere && (
                  <span
                    aria-hidden="true"
                    className="flex h-16 items-center px-1 text-base font-semibold text-texte-secondaire"
                  >
                    {repere}
                  </span>
                )}
                {jour.heures.length === 0 ? (
                  <span
                    aria-label={`${jour.libelle} : aucun créneau`}
                    className={`${forme} border-separateur bg-separateur text-texte-secondaire`}
                  >
                    {contenu}
                  </span>
                ) : (
                  <button
                    type="button"
                    ref={jour.cle === choisi ? refChoisi : undefined}
                    aria-pressed={jour.cle === choisi}
                    aria-label={jour.libelle}
                    onClick={() => onChoisir(jour.cle)}
                    className={`${forme} ${focus} ${
                      jour.cle === choisi
                        ? "border-accent bg-accent text-surface"
                        : "border-bordure bg-surface text-texte hover:bg-fond"
                    }`}
                  >
                    {contenu}
                  </button>
                )}
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
