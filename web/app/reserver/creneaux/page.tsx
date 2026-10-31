import type { Metadata } from "next";
import { Suspense } from "react";
import { EcranCreneaux, type CreneauxInitiaux } from "@/components/reservation/ecran-creneaux";
import { coiffeursCompetents, type Catalogue } from "@/lib/catalogue";
import { periode } from "@/lib/creneaux";
import { lireCreneauxServeur } from "@/lib/creneaux-serveur";
import { env } from "@/lib/env";
import { lireCatalogue } from "@/lib/lire-catalogue";

// Écran 2 du parcours : créneaux libres (BF-C1, BF-C3). La coquille de la page
// (catalogue en cache, message de chargement) reste statique ; la liste des
// créneaux est lue par le serveur à chaque visite et part dans le même HTML,
// derrière <Suspense> (#46, option A de Sparta, BNF-5) : elle s'affiche sans
// attendre le JavaScript, et chaque heure est un lien vers l'écran 3.
export const ensureStatic = "shell";

export const metadata: Metadata = {
  title: "Choisir un créneau · Salon RDV",
};

export default async function Creneaux({ searchParams }: PageProps<"/reserver/creneaux">) {
  const catalogue = await lireCatalogue(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 py-8 sm:px-8">
      <Suspense
        fallback={<p className="text-base text-texte-secondaire">Chargement des créneaux…</p>}
      >
        <CreneauxDeLaVisite catalogue={catalogue} searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

// Lu à chaque visite : prestation et coiffeur de l'URL, créneaux de la base.
// Si la lecture échoue, l'écran la refait côté navigateur (bouton
// « Réessayer » compris).
async function CreneauxDeLaVisite({
  catalogue,
  searchParams,
}: {
  catalogue: Catalogue;
  searchParams: PageProps<"/reserver/creneaux">["searchParams"];
}) {
  const params = await searchParams;
  const texte = (valeur: string | string[] | undefined) =>
    typeof valeur === "string" ? valeur : "";
  const prestationId = texte(params.prestation);
  const demande = texte(params.coiffeur);
  const coiffeurId = coiffeursCompetents(catalogue, prestationId).some((c) => c.id === demande)
    ? demande
    : "";

  let initiaux: CreneauxInitiaux | undefined;
  if (catalogue.prestations.some((p) => p.id === prestationId)) {
    const { du, au } = periode(new Date(), catalogue.fuseau);
    try {
      const creneaux = await lireCreneauxServeur({
        prestationId,
        du,
        au,
        coiffeurId: coiffeurId || undefined,
      });
      initiaux = { prestationId, coiffeurId, du, creneaux };
    } catch {
      initiaux = undefined;
    }
  }

  return <EcranCreneaux catalogue={catalogue} initiaux={initiaux} />;
}
