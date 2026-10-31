import Link from "next/link";
import { focus } from "@/components/ui/styles";
import { grouperParMoment, lienConfirmation, type Jour } from "@/lib/creneaux";

// Écran 2 : créneaux libres du jour choisi, rangés sous « Matin »,
// « Après-midi » et « Soir » (issue 130, option A de Sparta : tout visible,
// rien de replié) ; un moment sans créneau n'apparaît pas. Chaque heure mène à
// l'écran 3. Zones tactiles de 48 px, chiffres à chasse fixe ; 4 colonnes à
// 360 px.
export function ListeCreneaux({
  jour,
  prestationId,
  coiffeurId,
  depuisAccueil = false,
}: {
  jour: Jour;
  prestationId: string;
  coiffeurId?: string;
  depuisAccueil?: boolean;
}) {
  return (
    <section aria-labelledby={`jour-${jour.cle}`} className="flex flex-col gap-5">
      <h2 id={`jour-${jour.cle}`} className="font-titre text-xl font-medium text-texte">
        {jour.libelle}
      </h2>
      {grouperParMoment(jour.heures).map(({ moment, heures }) => {
        const id = `moment-${jour.cle}-${moment}`;
        return (
          <div key={moment} className="flex flex-col gap-2">
            <h3 id={id} className="text-base font-semibold text-texte-secondaire">
              {moment}
            </h3>
            <ul aria-labelledby={id} className="grid grid-cols-4 gap-2 sm:grid-cols-6">
              {heures.map((heure) => (
                <li key={heure.debut}>
                  {/* Pas de préchargement : des dizaines de liens, en 3G. */}
                  <Link
                    href={lienConfirmation(prestationId, heure.debut, coiffeurId, depuisAccueil)}
                    prefetch={false}
                    className={`flex h-12 items-center justify-center rounded-base border border-bordure bg-surface text-base font-semibold text-texte tabular-nums hover:border-accent hover:text-accent ${focus}`}
                  >
                    {heure.libelle}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        );
      })}
    </section>
  );
}
