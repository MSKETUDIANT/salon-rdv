"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { ReactNode } from "react";
import { focus } from "@/components/ui/styles";

// Navigation du site client (#53, charte §4) : les mêmes trois destinations,
// en barre d'onglets fixe en bas sur téléphone (moins de 768 px) et en liens
// dans l'en-tête sur ordinateur. L'onglet de la page en cours est signalé
// (aria-current, couleur accent, texte en gras).

type Destination = { href: string; libelle: string; icone: ReactNode };

// Icônes au trait (24 px, couleur du texte), décoratives : le libellé suffit.
function Icone({ children }: { children: ReactNode }) {
  return (
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
    >
      {children}
    </svg>
  );
}

const DESTINATIONS: Destination[] = [
  {
    href: "/",
    libelle: "Accueil",
    icone: (
      <Icone>
        <path d="M3 10.5 12 3l9 7.5" />
        <path d="M5 9v11a1 1 0 0 0 1 1h4v-6h4v6h4a1 1 0 0 0 1-1V9" />
      </Icone>
    ),
  },
  {
    href: "/reserver",
    libelle: "Réserver",
    icone: (
      <Icone>
        <rect x="3" y="5" width="18" height="16" rx="2" />
        <path d="M8 3v4M16 3v4M3 10h18M12 13v5M9.5 15.5h5" />
      </Icone>
    ),
  },
  {
    href: "/mes-reservations",
    libelle: "Mes réservations",
    icone: (
      <Icone>
        <rect x="5" y="3" width="14" height="18" rx="2" />
        <path d="M9 8h6M9 12h6M9 16h4" />
      </Icone>
    ),
  },
];

// Onglet courant : la page elle-même, ou une étape du parcours de réservation.
function estCourante(href: string, chemin: string): boolean {
  return href === "/" ? chemin === "/" : chemin === href || chemin.startsWith(`${href}/`);
}

// Ordinateur : liens dans l'en-tête, avec le nom du salon.
export function EnTeteNavigation({ nomSalon }: { nomSalon: string }) {
  const chemin = usePathname();
  return (
    <header className="hidden border-b border-separateur bg-surface md:block">
      <div className="mx-auto flex w-full max-w-2xl items-center justify-between gap-6 px-8 py-2">
        <Link
          href="/"
          className={`inline-flex min-h-11 items-center rounded-base font-titre text-xl font-medium text-texte ${focus}`}
        >
          {nomSalon}
        </Link>
        <nav aria-label="Navigation principale">
          <ul className="flex items-center gap-6">
            {DESTINATIONS.map(({ href, libelle }) => {
              const courante = estCourante(href, chemin);
              return (
                <li key={href}>
                  <Link
                    href={href}
                    aria-current={courante ? "page" : undefined}
                    className={`inline-flex min-h-11 items-center rounded-base text-base font-semibold ${focus} ${
                      courante ? "text-accent underline underline-offset-4" : "text-texte hover:text-accent"
                    }`}
                  >
                    {libelle}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>
      </div>
    </header>
  );
}

// Téléphone : barre d'onglets fixe en bas, icône et libellé. La marge du bas
// tient compte de la zone système des téléphones sans bouton (safe area).
export function BarreOnglets() {
  const chemin = usePathname();
  return (
    <nav
      aria-label="Navigation principale"
      className="fixed inset-x-0 bottom-0 z-10 border-t border-separateur bg-surface pb-[env(safe-area-inset-bottom)] md:hidden"
    >
      <ul className="mx-auto flex w-full max-w-2xl">
        {DESTINATIONS.map(({ href, libelle, icone }) => {
          const courante = estCourante(href, chemin);
          return (
            <li key={href} className="flex flex-auto">
              <Link
                href={href}
                aria-current={courante ? "page" : undefined}
                className={`flex min-h-16 flex-auto flex-col items-center justify-center gap-0.5 border-t-2 px-2 py-1 text-base whitespace-nowrap ${focus} ${
                  courante
                    ? "border-accent font-semibold text-accent"
                    : "border-transparent text-texte-secondaire hover:text-texte"
                }`}
              >
                {icone}
                {libelle}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
