import { EnTeteSalon } from "@/components/en-tete-salon";
import { PhotoAccueil } from "@/components/photo-accueil";
import { ListePrestations } from "@/components/reservation/carte-prestation";
import { adresseAccueil, semaineHoraires, titreAccueil } from "@/lib/accueil";
import { env } from "@/lib/env";
import { lireCatalogue } from "@/lib/lire-catalogue";
import { lireSalon } from "@/lib/salon";

// Page publique : doit rester statique (salon et catalogue en cache,
// revalidés chaque minute). Le build échoue si elle devient dynamique.
export const ensureStatic = "navigation";

export default async function Accueil() {
  const [salon, { prestations }] = await Promise.all([
    lireSalon(env.salonId),
    lireCatalogue(env.salonId),
  ]);

  const semaine = semaineHoraires(salon?.horaires ?? []);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 pt-4 pb-8 sm:px-8 sm:pt-8">
      <PhotoAccueil photo={salon?.photo ?? null} nom={titreAccueil(salon)} />
      <EnTeteSalon
        nom={titreAccueil(salon)}
        adresse={adresseAccueil(salon)}
        telephone={salon?.telephone ?? null}
        reserver={prestations.length > 0 ? "#prestations" : "/reserver"}
      />
      {/* Prestations et prix avant de réserver (issue 129) : même liste que
          l'écran 1, un toucher mène aux créneaux de la prestation. Le bouton
          « Réserver » de l'en-tête descend ici (option A, comme Planity). */}
      {prestations.length > 0 && (
        <section
          id="prestations"
          aria-labelledby="titre-prestations"
          className="flex scroll-mt-4 flex-col gap-4 md:scroll-mt-20"
        >
          <h2 id="titre-prestations" className="font-titre text-xl font-medium text-texte">
            Prestations
          </h2>
          <ListePrestations prestations={prestations} />
        </section>
      )}
      {/* Horaires d'ouverture (issue 129) : la semaine entière, comme Google
          Maps ; jours alignés à gauche, heures à droite. */}
      {semaine.length > 0 && (
        <section aria-labelledby="titre-horaires" className="flex flex-col gap-4 pt-8">
          <h2 id="titre-horaires" className="font-titre text-xl font-medium text-texte">
            Horaires
          </h2>
          <dl className="flex flex-col">
            {semaine.map(({ jour, heures }) => (
              <div
                key={jour}
                className="flex justify-between gap-4 border-b border-separateur py-3 text-base"
              >
                <dt className="text-texte">{jour}</dt>
                <dd
                  className={`tabular-nums ${heures === "Fermé" ? "text-texte-secondaire" : "text-texte"}`}
                >
                  {heures}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
    </main>
  );
}
