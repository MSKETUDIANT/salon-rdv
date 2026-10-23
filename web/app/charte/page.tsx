import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { Carte } from "@/components/ui/carte";
import { Champ } from "@/components/ui/champ";
import { couleurs, couples, tailles, valeur } from "@/lib/charte";
import { contraste } from "@/lib/contraste";

// Vitrine de la charte, pour validation visuelle sur les previews. Absente en
// production : Vercel fixe VERCEL_ENV=production au build de main, la page
// devient alors un 404 généré au build (elle reste statique).
export const ensureStatic = "navigation";

export const metadata: Metadata = {
  title: "Charte · Salon RDV",
  robots: { index: false, follow: false },
};

function Section({ titre, children }: { titre: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-4 border-t border-separateur pt-8">
      <h2 className="font-titre text-xl font-medium text-texte">{titre}</h2>
      {children}
    </section>
  );
}

export default function Charte() {
  if (process.env.VERCEL_ENV === "production") {
    notFound();
  }

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-col gap-8 px-4 py-8 sm:px-8">
      <header className="flex flex-col gap-2">
        <h1 className="font-titre text-3xl font-medium text-texte">Charte graphique</h1>
        <p className="text-base text-texte-secondaire">
          Référence : docs/charte-graphique.md. Page visible en local et sur les
          previews, jamais en production.
        </p>
      </header>

      <Section titre="Couleurs">
        <ul className="grid gap-3 sm:grid-cols-2">
          {couleurs.map((c) => (
            <li key={c.jeton} className="flex items-center gap-3">
              <span aria-hidden="true" className={`size-12 shrink-0 rounded-base border border-separateur ${c.classe}`} />
              <span className="flex flex-col">
                <span className="text-base font-semibold text-texte">
                  {c.jeton} <span className="font-normal tabular-nums text-texte-secondaire">{c.valeur}</span>
                </span>
                <span className="text-base text-texte-secondaire">{c.usage}</span>
              </span>
            </li>
          ))}
        </ul>
      </Section>

      <Section titre="Contrastes (WCAG 2.2 AA)">
        <ul className="flex flex-col gap-2">
          {couples.map((c) => {
            const ratio = contraste(valeur(c.avant), valeur(c.fond));
            return (
              <li key={`${c.avant}-${c.fond}`} className="text-base text-texte">
                <span className="font-semibold">{c.avant}</span> sur <span className="font-semibold">{c.fond}</span> :{" "}
                <span className="tabular-nums">{ratio.toFixed(1).replace(".", ",")}:1</span>{" "}
                <span className="text-texte-secondaire">
                  (seuil {String(c.seuil).replace(".", ",")}:1, {c.usage})
                </span>
              </li>
            );
          })}
        </ul>
      </Section>

      <Section titre="Typographie">
        {tailles.map((t) => (
          <div key={t.classe} className="flex flex-col">
            <span className={`font-titre ${t.classe} text-texte`}>Newsreader {t.px} px</span>
            <span className={`font-texte ${t.classe} text-texte`}>Figtree {t.px} px</span>
          </div>
        ))}
        <p className="text-base text-texte">
          Créneaux en chiffres à chasse fixe :{" "}
          <span className="tabular-nums">09:00 · 10:30 · 11:15 · 14:00</span>
        </p>
      </Section>

      <Section titre="Boutons">
        <p className="text-base text-texte-secondaire">
          48 px de haut. Utiliser Tab pour voir le focus (contour accent 2 px,
          décalé de 2 px). Pas de bouton désactivé.
        </p>
        <div className="flex flex-wrap gap-3">
          <Bouton>Principal</Bouton>
          <Bouton variante="secondaire">Secondaire</Bouton>
          <Bouton chargement>Principal</Bouton>
          <Bouton variante="secondaire" chargement>
            Secondaire
          </Bouton>
          <BoutonLien href="/reserver">Lien bouton</BoutonLien>
        </div>
      </Section>

      <Section titre="Champs de saisie">
        <div className="flex max-w-md flex-col gap-4">
          <Champ libelle="Adresse e-mail" type="email" placeholder="vous@exemple.fr" />
          <Champ libelle="Code reçu par e-mail" inputMode="numeric" autoComplete="one-time-code" defaultValue="12345" erreur="Le code doit contenir 6 chiffres." />
        </div>
      </Section>

      <Section titre="Cartes">
        <div className="grid gap-3 sm:grid-cols-2">
          <Carte>
            <p className="font-titre text-lg font-medium text-texte">Carte simple</p>
            <p className="text-base text-texte-secondaire">Bordure décorative « separateur ».</p>
          </Carte>
          <Carte cliquable>
            <p className="font-titre text-lg font-medium text-texte">Coupe femme</p>
            <p className="text-base tabular-nums text-texte-secondaire">45 min</p>
            <p className="text-base text-texte-secondaire">Carte cliquable : bordure « bordure » (3:1).</p>
          </Carte>
        </div>
      </Section>

      <Section titre="Créneau indisponible">
        <span className="inline-flex h-12 w-fit items-center rounded-base bg-separateur px-5 text-base tabular-nums text-texte-secondaire">
          10:30 · indisponible
        </span>
      </Section>
    </main>
  );
}
