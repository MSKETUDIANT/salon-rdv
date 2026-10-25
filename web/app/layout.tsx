import type { Metadata, Viewport } from "next";
import { Figtree, Newsreader } from "next/font/google";
import { BarreOnglets, EnTeteNavigation } from "@/components/navigation/navigation-site";
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

// Navigation (#53) : logo et liens dans l'en-tête à partir de 768 px (#55),
// barre d'onglets fixe en bas en dessous.
export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="fr"
      className={`${newsreader.variable} ${figtree.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col">
        <EnTeteNavigation />
        {children}
        {/* Réserve la hauteur de la barre d'onglets : rien n'est masqué dessous. */}
        <div aria-hidden="true" className="h-[calc(4.5rem+env(safe-area-inset-bottom))] md:hidden" />
        <BarreOnglets />
      </body>
    </html>
  );
}
