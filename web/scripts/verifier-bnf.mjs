// Issue #12 : vérification automatique des besoins non fonctionnels, en une
// commande (depuis web/) :
//
//   npm run verifier:bnf            tests sur la base locale
//   npm run verifier:bnf -- --perf  et, en plus, la mesure BNF-5 sur la
//                                   production (lecture seule)
//
// Prérequis : base locale démarrée (`supabase start`), Chrome installé,
// Flutter dans le PATH. Toutes les étapes tournent, même après un échec ; le
// code de sortie vaut 1 si l'une d'elles échoue. Résultats et écarts :
// docs/resultats-bnf.md.

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const web = fileURLToPath(new URL("..", import.meta.url));
const racine = fileURLToPath(new URL("../..", import.meta.url));
const pro = fileURLToPath(new URL("../../pro", import.meta.url));

const etapes = [
  { nom: "Base : tests SQL (BNF-1, BNF-2, BNF-3)", commande: "supabase test db", dossier: racine },
  { nom: "Site : tests unitaires et couverture (BNF-6, BNF-11)", commande: "npm run test:couverture", dossier: web },
  {
    nom: "Site : bout en bout (BNF-1, BNF-3, BNF-7, BNF-9, BNF-10, BNF-11)",
    commande: "npm run test:e2e",
    dossier: web,
  },
  { nom: "App pro : analyse", commande: "flutter analyze", dossier: pro },
  { nom: "App pro : tests et couverture (BNF-6)", commande: "flutter test --coverage", dossier: pro },
];
if (process.argv.includes("--perf")) {
  etapes.push({ nom: "Production : performance en 3G (BNF-5)", commande: "npm run mesurer:bnf5", dossier: web });
}

const statut = spawnSync("supabase status", { cwd: racine, shell: true, stdio: "ignore" });
if (statut.status !== 0) {
  console.error("Base locale arrêtée : lancez `supabase start`, puis relancez.");
  process.exit(1);
}

const bilan = [];
for (const etape of etapes) {
  console.log(`\n=== ${etape.nom}\n$ ${etape.commande}\n`);
  const debut = Date.now();
  const r = spawnSync(etape.commande, { cwd: etape.dossier, shell: true, stdio: "inherit" });
  bilan.push({ ...etape, ok: r.status === 0, secondes: Math.round((Date.now() - debut) / 1000) });
}

console.log("\n=== Bilan");
for (const b of bilan) console.log(`${b.ok ? "OK    " : "ÉCHEC "} ${b.nom} (${b.secondes} s)`);
process.exit(bilan.every((b) => b.ok) ? 0 : 1);
