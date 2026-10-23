"use client";

import type { ButtonHTMLAttributes, MouseEvent } from "react";
import { classesBouton, type VarianteBouton } from "@/components/ui/styles";

// Pas de prop `disabled` : la charte interdit le bouton désactivé dans le
// parcours. Pendant le chargement, le bouton reste focusable mais ignore les
// clics (souris, Entrée, Espace, soumission implicite d'un formulaire).
type Props = Omit<ButtonHTMLAttributes<HTMLButtonElement>, "disabled"> & {
  variante?: VarianteBouton;
  chargement?: boolean;
  libelleChargement?: string;
};

export function Bouton({
  variante = "principal",
  chargement = false,
  libelleChargement = "Chargement…",
  type = "button",
  onClick,
  className,
  children,
  ...props
}: Props) {
  function gererClic(evenement: MouseEvent<HTMLButtonElement>) {
    if (chargement) {
      // Empêche aussi l'envoi du formulaire quand type="submit".
      evenement.preventDefault();
      return;
    }
    onClick?.(evenement);
  }

  return (
    <button
      {...props}
      type={type}
      aria-busy={chargement || undefined}
      onClick={gererClic}
      className={`${classesBouton[variante]} ${className ?? ""}`}
    >
      {chargement ? libelleChargement : children}
    </button>
  );
}
