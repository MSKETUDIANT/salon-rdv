import Link from "next/link";
import type { ReactNode } from "react";
import { classesBouton, type VarianteBouton } from "@/components/ui/styles";

// Lien qui a l'apparence d'un bouton (navigation, ex. « Réserver »).
export function BoutonLien({
  href,
  variante = "principal",
  children,
}: {
  href: string;
  variante?: VarianteBouton;
  children: ReactNode;
}) {
  return (
    <Link href={href} className={classesBouton[variante]}>
      {children}
    </Link>
  );
}
