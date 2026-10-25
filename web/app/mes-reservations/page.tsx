import type { Metadata } from "next";
import { EcranMesReservations } from "@/components/mes-reservations/ecran-mes-reservations";
import { env } from "@/lib/env";
import { lireCatalogue } from "@/lib/lire-catalogue";

// « Mes réservations » (BF-C6). Les réservations sont lues côté navigateur,
// avec la session du client : la page reste statique.
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Mes réservations · Salon RDV",
};

export default async function MesReservations() {
  const { fuseau } = await lireCatalogue(env.salonId);

  return (
    <main className="mx-auto flex w-full max-w-2xl flex-1 flex-col px-4 py-8 sm:px-8">
      <EcranMesReservations salonId={env.salonId} fuseau={fuseau} />
    </main>
  );
}
