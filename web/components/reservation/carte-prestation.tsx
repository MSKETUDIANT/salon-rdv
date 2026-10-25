import Link from "next/link";
import { Carte } from "@/components/ui/carte";
import { focus } from "@/components/ui/styles";
import type { Prestation } from "@/lib/catalogue";
import { formatDuree, formatPrix } from "@/lib/format";

// Écran 1 : une prestation, sans photo (charte §7). Toute la carte est le lien
// vers l'écran 2 : nom, durée et prix séparés (prix en gras), chevron (#55).
export function CartePrestation({ prestation }: { prestation: Prestation }) {
  return (
    <Link
      href={`/reserver/creneaux?prestation=${prestation.id}`}
      className={`group block rounded-base ${focus}`}
    >
      <Carte cliquable className="flex items-center gap-3 group-hover:bg-fond">
        <span className="flex min-w-0 flex-1 flex-col gap-1">
          <span className="text-lg font-semibold break-words text-texte">{prestation.nom}</span>
          <span className="flex flex-wrap items-baseline gap-x-3 text-base tabular-nums">
            <span className="text-texte-secondaire">{formatDuree(prestation.dureeMinutes)}</span>
            <span className="font-semibold text-texte">{formatPrix(prestation.prix)}</span>
          </span>
        </span>
        <svg
          aria-hidden="true"
          viewBox="0 0 24 24"
          width="24"
          height="24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="shrink-0 text-accent"
        >
          <path d="m9 6 6 6-6 6" />
        </svg>
      </Carte>
    </Link>
  );
}
