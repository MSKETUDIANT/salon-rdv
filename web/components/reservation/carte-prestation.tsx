import Link from "next/link";
import { focus } from "@/components/ui/styles";
import type { Prestation } from "@/lib/catalogue";
import { formatDuree, formatPrix } from "@/lib/format";

// Une prestation, en ligne de liste sans cadre (comme Planity ; remarque de
// Sparta sur les cartes encadrées, issue 129) : nom, puis durée et prix exact
// (prix en gras, jamais « à partir de »), bouton « Choisir » à droite. Toute
// la ligne est le lien vers l'écran 2. Sans photo (charte §7).
export function CartePrestation({ prestation }: { prestation: Prestation }) {
  return (
    <Link
      href={`/reserver/creneaux?prestation=${prestation.id}`}
      className={`group -mx-2 flex min-h-18 items-center gap-4 rounded-base px-2 py-3 hover:bg-surface ${focus}`}
    >
      <span className="flex min-w-0 flex-1 flex-col gap-1">
        <span className="text-lg font-semibold break-words text-texte">{prestation.nom}</span>
        <span className="flex flex-wrap items-baseline gap-x-2 text-base tabular-nums">
          <span className="text-texte-secondaire">{formatDuree(prestation.dureeMinutes)}</span>
          <span aria-hidden="true" className="text-texte-secondaire">
            ·
          </span>
          <span className="font-semibold text-texte">{formatPrix(prestation.prix)}</span>
        </span>
      </span>
      <span className="inline-flex h-11 shrink-0 items-center rounded-base border border-bordure bg-surface px-4 text-base font-semibold text-accent group-hover:border-accent">
        Choisir
      </span>
    </Link>
  );
}

// Liste des prestations (accueil et écran 1) : filets fins entre les lignes,
// pas de cartes encadrées.
export function ListePrestations({ prestations }: { prestations: Prestation[] }) {
  return (
    <ul className="flex flex-col border-t border-separateur">
      {prestations.map((prestation) => (
        <li key={prestation.id} className="border-b border-separateur">
          <CartePrestation prestation={prestation} />
        </li>
      ))}
    </ul>
  );
}
