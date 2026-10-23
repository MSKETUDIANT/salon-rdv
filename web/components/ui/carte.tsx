import type { HTMLAttributes } from "react";

// Carte : fond `surface`, coins 8 px, sans ombre. Bordure décorative
// `separateur` ; une carte cliquable (ex. choix de prestation, #5) prend la
// bordure `bordure` (3:1), car elle délimite un élément interactif. Le clic
// lui-même est porté par le bouton ou le lien qui l'enveloppe.
type Props = HTMLAttributes<HTMLDivElement> & { cliquable?: boolean };

export function Carte({ cliquable = false, className, children, ...props }: Props) {
  return (
    <div
      {...props}
      className={`rounded-base border bg-surface p-4 ${
        cliquable ? "border-bordure" : "border-separateur"
      } ${className ?? ""}`}
    >
      {children}
    </div>
  );
}
