// Issue #12, BNF-5 (performance) : temps d'affichage de la liste des
// créneaux sur le site de PRODUCTION, en 3G simulée, profil de téléphone
// d'entrée de gamme. Lecture seule : aucune réservation n'est faite.
//
//   node scripts/bnf5-performance.mjs [url du site] [--profil=lighthouse]
//
// Profil de référence (« 3g ») : préréglage « Fast 3G » des DevTools de Chrome
// (débit descendant 1,6 Mb/s × 0,9, montant 750 kb/s × 0,9, latence
// 562,5 ms). Profil de comparaison (« lighthouse ») : réseau mobile simulé de
// Lighthouse (1,6 Mb/s, 750 kb/s, 150 ms). Dans les deux cas : processeur
// ralenti 4 fois, écran 360 × 800, tactile. Chaque mesure part d'un navigateur
// neuf (sans cache). Un appel de préchauffage, non compté, réveille d'abord le
// site et la base (fonctions serverless « à froid »), puis 5 mesures.
// Mesure : du début de la navigation vers l'écran 2 jusqu'à l'affichage de la
// première heure proposée. Seuil du cahier des charges : 3 s.

import { chromium } from "@playwright/test";

const args = process.argv.slice(2);
const SITE = args.find((a) => !a.startsWith("--")) ?? "https://salon-rdv-one.vercel.app";
const PROFIL = args.find((a) => a.startsWith("--profil="))?.split("=")[1] ?? "3g";
const MESURES = 5;
const SEUIL_MS = 3000;
const PROFILS = {
  "3g": {
    nom: "Fast 3G (DevTools) + processeur ×4, 360 × 800, sans cache",
    reseau: {
      offline: false,
      latency: 562.5,
      downloadThroughput: ((1.6 * 1024 * 1024) / 8) * 0.9,
      uploadThroughput: ((750 * 1024) / 8) * 0.9,
    },
  },
  lighthouse: {
    nom: "réseau mobile Lighthouse (1,6 Mb/s, 150 ms) + processeur ×4, 360 × 800, sans cache",
    reseau: {
      offline: false,
      latency: 150,
      downloadThroughput: (1.6 * 1024 * 1024) / 8,
      uploadThroughput: (750 * 1024) / 8,
    },
  },
};
const RESEAU = PROFILS[PROFIL].reseau;

const navigateur = await chromium.launch({ channel: "chrome" });

async function nouvellePage({ bride }) {
  const contexte = await navigateur.newContext({
    viewport: { width: 360, height: 800 },
    isMobile: true,
    hasTouch: true,
    locale: "fr-FR",
  });
  const page = await contexte.newPage();
  if (bride) {
    const cdp = await contexte.newCDPSession(page);
    await cdp.send("Network.enable");
    await cdp.send("Network.setCacheDisabled", { cacheDisabled: true });
    await cdp.send("Network.emulateNetworkConditions", RESEAU);
    await cdp.send("Emulation.setCPUThrottlingRate", { rate: 4 });
  }
  return { contexte, page };
}

// Adresse de l'écran 2 pour la première prestation du salon de démo.
const { contexte: c0, page: p0 } = await nouvellePage({ bride: false });
await p0.goto(`${SITE}/reserver`);
const lienPrestation = p0.locator('a[href*="/reserver/creneaux?"]').first();
await lienPrestation.waitFor();
const ecran2 = new URL((await lienPrestation.getAttribute("href")), SITE).toString();
const prestation = (await lienPrestation.textContent()).trim().replace(/\s+/g, " ");
await c0.close();

async function mesurer({ bride }) {
  const { contexte, page } = await nouvellePage({ bride });
  const depart = Date.now();
  await page.goto(ecran2, { waitUntil: "commit" });
  await page.getByRole("link", { name: /^\d{2}:\d{2}$/ }).first().waitFor({ timeout: 60_000 });
  const duree = Date.now() - depart;
  // Décomposition (Navigation Timing) : où passe le temps.
  const etapes = await page.evaluate(() => {
    const n = performance.getEntriesByType("navigation")[0];
    const r = (x) => Math.round(x);
    return {
      connexion_ms: r(n.connectEnd - n.startTime),
      premier_octet_ms: r(n.responseStart - n.startTime),
      html_complet_ms: r(n.responseEnd - n.startTime),
      ressources: performance.getEntriesByType("resource").length,
      ko_js: Math.round(
        performance
          .getEntriesByType("resource")
          .filter((e) => e.initiatorType === "script")
          .reduce((t, e) => t + e.transferSize, 0) / 1024,
      ),
    };
  });
  await contexte.close();
  detail.push({ duree, ...etapes });
  return duree;
}
const detail = [];

const prechauffage = await mesurer({ bride: false });
const durees = [];
for (let i = 0; i < MESURES; i++) durees.push(await mesurer({ bride: true }));
await navigateur.close();

const tries = [...durees].sort((a, b) => a - b);
const mediane = tries[Math.floor(tries.length / 2)];
const resultat = {
  site: SITE,
  ecran2,
  prestation,
  profil: PROFILS[PROFIL].nom,
  prechauffage_ms: prechauffage,
  mesures_ms: durees,
  decomposition: detail.slice(1),
  mediane_ms: mediane,
  min_ms: tries[0],
  max_ms: tries.at(-1),
  seuil_ms: SEUIL_MS,
  reussi: mediane < SEUIL_MS,
  date: new Date().toISOString(),
};
console.log(JSON.stringify(resultat, null, 2));
process.exit(resultat.reussi ? 0 : 1);
