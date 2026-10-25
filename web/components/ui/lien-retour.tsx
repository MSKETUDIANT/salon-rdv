import Link from "next/link";
import { focus } from "@/components/ui/styles";

// « ← Retour » en haut de chaque étape du parcours (#53), toujours au même
// endroit et avec le même libellé. Un vrai lien vers l'étape précédente (et
// non history.back()) : il marche aussi quand l'écran a été ouvert
// directement. vers : nom de l'étape précédente, lu par les lecteurs d'écran.
export function LienRetour({ href, vers }: { href: string; vers: string }) {
  return (
    <Link
      href={href}
      aria-label={`Retour ${vers}`}
      className={`inline-flex min-h-11 items-center gap-1 self-start rounded-base text-base font-semibold text-accent underline ${focus}`}
    >
      <span aria-hidden="true">←</span> Retour
    </Link>
  );
}
