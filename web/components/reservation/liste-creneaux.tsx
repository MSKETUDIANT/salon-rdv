import Link from "next/link";
import { focus } from "@/components/ui/styles";
import { lienConfirmation, type Jour } from "@/lib/creneaux";

// Écran 2 : créneaux libres par jour. Chaque heure mène à l'écran 3. Zones
// tactiles de 48 px, chiffres à chasse fixe ; 4 colonnes à 360 px.
export function ListeCreneaux({
  jours,
  prestationId,
  coiffeurId,
}: {
  jours: Jour[];
  prestationId: string;
  coiffeurId?: string;
}) {
  return (
    <div className="flex flex-col gap-6">
      {jours.map((jour) => (
        <section key={jour.cle} aria-labelledby={`jour-${jour.cle}`} className="flex flex-col gap-3">
          <h2 id={`jour-${jour.cle}`} className="font-titre text-xl font-medium text-texte">
            {jour.libelle}
          </h2>
          <ul className="grid grid-cols-4 gap-2 sm:grid-cols-6">
            {jour.heures.map((heure) => (
              <li key={heure.debut}>
                {/* Pas de préchargement : des centaines de liens, en 3G. */}
                <Link
                  href={lienConfirmation(prestationId, heure.debut, coiffeurId)}
                  prefetch={false}
                  className={`flex h-12 items-center justify-center rounded-base border border-bordure bg-surface text-base font-semibold text-texte tabular-nums hover:bg-fond ${focus}`}
                >
                  {heure.libelle}
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}
