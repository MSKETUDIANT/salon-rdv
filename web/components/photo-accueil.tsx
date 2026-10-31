"use client";

import Image from "next/image";
import { useState } from "react";
import photoDemo from "@/public/accueil-salon.webp";

// Photo de la page d'accueil, jamais de texte dessus (charte §6). Celle
// envoyée par le gérant dans l'app pro (issue 117), recadrée en 4:3 ; sinon la
// photo de démonstration, déjà en 4:3 (1600 × 1200, source dans
// docs/charte-graphique.md §6). Si la photo du gérant ne se charge pas (page
// encore en cache après un changement de photo : l'ancien fichier est déjà
// supprimé), la photo de démonstration la remplace : jamais d'image cassée.
export function PhotoAccueil({ photo, nom }: { photo: string | null; nom: string }) {
  const [echec, setEchec] = useState(false);
  const sizes = "(min-width: 42rem) 608px, calc(100vw - 2rem)";
  if (!photo || echec) {
    return (
      <Image
        src={photoDemo}
        alt="Fauteuil de coiffure devant un meuble en bois et un miroir rond"
        sizes={sizes}
        preload
        className="aspect-4/3 h-auto w-full rounded-base object-cover"
      />
    );
  }
  return (
    <div className="relative aspect-4/3 w-full overflow-hidden rounded-base">
      <Image
        src={photo}
        alt={`Photo du salon ${nom}`}
        fill
        sizes={sizes}
        preload
        className="object-cover"
        onError={() => setEchec(true)}
      />
    </div>
  );
}
