// Garde-fou de la charte graphique (docs/charte-graphique.md), lancé par
// `npm run lint` : aucune couleur, taille de texte, ombre ou arrondi hors des
// jetons de app/globals.css dans app/ et components/. Code de sortie 1 sinon.
import { readdirSync, readFileSync } from "node:fs";
import { extname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const racine = fileURLToPath(new URL("..", import.meta.url));
const dossiers = ["app", "components"];
const extensions = new Set([".ts", ".tsx", ".css", ".mjs", ".js"]);
const exclus = new Set(["app/globals.css"]); // seul endroit où vivent les jetons

const palette =
  "slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose|black|white";

const regles = [
  { nom: "code hexadécimal", motif: /#[0-9a-fA-F]{3,8}\b/g },
  { nom: "classe de palette brute", motif: new RegExp(`\\b[a-z]+(?:-[a-z]+)*-(?:${palette})(?:-\\d{2,3})?(?:\\/\\d+)?\\b`, "g") },
  { nom: "taille de texte hors charte", motif: /\btext-(?:xs|sm|[4-9]xl)\b/g },
  { nom: "ombre", motif: /\bshadow(?:-[a-z0-9-]+)?(?![\w-])/g },
  { nom: "arrondi hors charte", motif: /\brounded(?:-(?!base\b|none\b|pastille\b)[a-z0-9-]+)?(?![\w-])/g },
  { nom: "mode sombre", motif: /\bdark:/g },
];

function* fichiers(dossier) {
  for (const entree of readdirSync(dossier, { withFileTypes: true })) {
    const chemin = join(dossier, entree.name);
    if (entree.isDirectory()) yield* fichiers(chemin);
    else if (extensions.has(extname(entree.name))) yield chemin;
  }
}

const erreurs = [];
for (const dossier of dossiers) {
  for (const chemin of fichiers(join(racine, dossier))) {
    const relatif = relative(racine, chemin).replaceAll("\\", "/");
    if (exclus.has(relatif)) continue;
    readFileSync(chemin, "utf8").split("\n").forEach((ligne, i) => {
      for (const { nom, motif } of regles) {
        for (const [trouve] of ligne.matchAll(motif)) {
          erreurs.push(`${relatif}:${i + 1}  ${nom} : ${trouve}`);
        }
      }
    });
  }
}

if (erreurs.length > 0) {
  console.error(`Charte graphique : ${erreurs.length} valeur(s) hors jetons (voir docs/charte-graphique.md)`);
  for (const erreur of erreurs) console.error(`  ${erreur}`);
  process.exit(1);
}
console.log("Charte graphique : aucune valeur hors jetons dans app/ et components/.");
