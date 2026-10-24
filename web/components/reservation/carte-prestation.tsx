import Link from "next/link";
import { Carte } from "@/components/ui/carte";
import { focus } from "@/components/ui/styles";
import type { Prestation } from "@/lib/catalogue";
import { formatDuree, formatPrix } from "@/lib/format";

// Écran 1 : une prestation, sans photo (charte §7). Toute la carte est le lien
// vers l'écran 2.
export function CartePrestation({ prestation }: { prestation: Prestation }) {
  return (
    <Link
      href={`/reserver/creneaux?prestation=${prestation.id}`}
      className={`group block rounded-base ${focus}`}
    >
      <Carte cliquable className="flex flex-col gap-1 group-hover:bg-fond">
        <span className="text-lg font-semibold text-texte">{prestation.nom}</span>
        <span className="text-base text-texte-secondaire tabular-nums">
          {formatDuree(prestation.dureeMinutes)} · {formatPrix(prestation.prix)}
        </span>
      </Carte>
    </Link>
  );
}
