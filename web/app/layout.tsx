import type { Metadata, Viewport } from "next";
import { Figtree, Newsreader } from "next/font/google";
import { BarreOnglets, EnTeteNavigation } from "@/components/navigation/navigation-site";
import { titreAccueil } from "@/lib/accueil";
import { env } from "@/lib/env";
import { lireSalon } from "@/lib/salon";
import "./globals.css";

// Polices de la charte, auto-hébergées par next/font (téléchargées au build,
// servies par le site). Versions variables : un fichier par police.
const newsreader = Newsreader({
  variable: "--font-newsreader",
  subsets: ["latin"],
  display: "swap",
});

const figtree = Figtree({
  variable: "--font-figtree",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Salon RDV",
  description: "Réservez votre rendez-vous au salon, sans application à installer.",
};

// viewport-fit=cover : la barre d'onglets lit la zone système du bas
// (env(safe-area-inset-bottom)) sur les téléphones sans bouton.
export const viewport: Viewport = { viewportFit: "cover" };

// Navigation (#53) : liens dans l'en-tête à partir de 768 px, barre d'onglets
// fixe en bas en dessous. Nom du salon en cache, comme sur l'accueil.
export default async function RootLayout({ children }: LayoutProps<"/">) {
  let nomSalon = "Salon RDV";
  try {
    nomSalon = titreAccueil(await lireSalon(env.salonId));
  } catch {
    // Nom illisible : l'en-tête garde le nom générique, le site reste servi.
  }

  return (
    <html
      lang="fr"
      className={`${newsreader.variable} ${figtree.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col">
        <EnTeteNavigation nomSalon={nomSalon} />
        {children}
        {/* Réserve la hauteur de la barre d'onglets : rien n'est masqué dessous. */}
        <div aria-hidden="true" className="h-[calc(4.5rem+env(safe-area-inset-bottom))] md:hidden" />
        <BarreOnglets />
      </body>
    </html>
  );
}
