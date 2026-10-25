import Link from "next/link";
import { lienSecondaire } from "@/components/ui/styles";

// « ‹ Retour » en haut de chaque étape du parcours (#53), toujours au même
// endroit et avec le même libellé ; style des liens secondaires (#55). Un vrai
// lien vers l'étape précédente (et non history.back()) : il marche aussi
// quand l'écran a été ouvert directement. vers : nom de l'étape précédente,
// lu par les lecteurs d'écran.
export function LienRetour({
  href,
  vers,
  libelle = "Retour",
}: {
  href: string;
  vers: string;
  libelle?: string;
}) {
  return (
    <Link href={href} aria-label={`Retour ${vers}`} className={lienSecondaire}>
      <svg
        aria-hidden="true"
        viewBox="0 0 24 24"
        width="20"
        height="20"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="m15 6-6 6 6 6" />
      </svg>
      {libelle}
    </Link>
  );
}
