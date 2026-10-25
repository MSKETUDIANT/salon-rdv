import AxeBuilder from "@axe-core/playwright";
import { expect, test, type Page } from "@playwright/test";
import { creneauLibre, emailUnique, SEED, seConnecter } from "./outils";

// Issue #12 : chaque écran du site client, dans ses différents états, à
// 360 px de large (config Playwright).
//   BNF-10 (cahier des charges) : pas de défilement horizontal, zones tactiles
//   d'au moins 44 × 44 px, texte d'au moins 16 px.
//   BNF-11 : contrastes WCAG 2.2 AA, audit axe-core (règle color-contrast).
// Les autres règles axe (WCAG 2.2 A et AA) sont relevées sans faire échouer
// le test : elles vont dans le rapport (docs/resultats-bnf.md).

type Mesure = {
  largeurPage: number;
  largeurEcran: number;
  petitesZones: string[];
  petitsTextes: string[];
};

// Mesures faites dans la page : éléments visibles seulement. Largeur de
// référence : celle de l'écran émulé (360 px), pas window.innerWidth, qu'un
// navigateur mobile agrandit quand le contenu déborde.
async function mesurer(page: Page): Promise<Mesure> {
  const largeurEcran = page.viewportSize()!.width;
  const m = await page.evaluate(() => {
    const visible = (el: Element) => {
      const r = el.getBoundingClientRect();
      const s = getComputedStyle(el);
      return r.width > 0 && r.height > 0 && s.visibility !== "hidden" && s.display !== "none";
    };
    const decrire = (el: Element, detail: string) =>
      `${el.tagName.toLowerCase()} « ${(el.textContent || el.getAttribute("aria-label") || "").trim().slice(0, 40)} » ${detail}`;

    const petitesZones: string[] = [];
    const interactifs = document.querySelectorAll(
      'a[href], button, input:not([type="hidden"]), select, textarea, summary, [role="button"], [role="link"]',
    );
    for (const el of interactifs) {
      if (!visible(el)) continue;
      const r = el.getBoundingClientRect();
      if (r.width < 44 || r.height < 44) {
        petitesZones.push(decrire(el, `${Math.round(r.width)} × ${Math.round(r.height)} px`));
      }
    }

    const petitsTextes: string[] = [];
    const parcours = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
    const vus = new Set<Element>();
    for (let n = parcours.nextNode(); n; n = parcours.nextNode()) {
      const el = n.parentElement;
      if (!el || vus.has(el) || !n.textContent?.trim() || !visible(el)) continue;
      vus.add(el);
      const taille = parseFloat(getComputedStyle(el).fontSize);
      if (taille < 16) petitsTextes.push(decrire(el, `${taille} px`));
    }

    return {
      largeurPage: document.documentElement.scrollWidth,
      petitesZones,
      petitsTextes,
    };
  });
  return { ...m, largeurEcran };
}

async function verifier(page: Page, ecran: string) {
  await page.waitForLoadState("networkidle");
  const m = await mesurer(page);
  const axe = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"]).analyze();
  const contrastes = axe.violations.filter((v) => v.id === "color-contrast");
  const autres = axe.violations.filter((v) => v.id !== "color-contrast");

  test.info().annotations.push({
    type: `BNF-10/11 ${ecran}`,
    description:
      `largeur ${m.largeurPage}/${m.largeurEcran} px ; zones < 44 px : ${m.petitesZones.length} ; ` +
      `textes < 16 px : ${m.petitsTextes.length} ; contrastes : ${contrastes.length} ; ` +
      `autres règles axe : ${autres.map((v) => `${v.id} (${v.nodes.length})`).join(", ") || "aucune"}`,
  });

  expect.soft(m.largeurPage, `${ecran} : défilement horizontal`).toBeLessThanOrEqual(m.largeurEcran);
  expect.soft(m.petitesZones, `${ecran} : zones tactiles < 44 × 44 px`).toEqual([]);
  expect.soft(m.petitsTextes, `${ecran} : textes < 16 px`).toEqual([]);
  expect
    .soft(
      contrastes.flatMap((v) => v.nodes.map((n) => n.target.join(" "))),
      `${ecran} : contrastes insuffisants (axe-core)`,
    )
    .toEqual([]);
}

// Contrôle des mesures elles-mêmes : sur une page aux défauts connus, chacun
// est bien détecté (sinon « 0 écart » ne prouverait rien).
test("les mesures détectent les défauts : défilement, petite zone, petit texte, contraste", async ({ page }) => {
  await page.setContent(`<!doctype html><html lang="fr"><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Défauts</title></head><body style="margin:0;font-size:16px">
    <main><h1>Défauts</h1>
    <div style="width:500px">Trop large</div>
    <button style="width:30px;height:30px;font-size:16px">x</button>
    <p style="font-size:12px">Petit texte</p>
    <p style="color:#bbbbbb;background:#ffffff">Contraste faible</p></main></body></html>`);
  const m = await mesurer(page);
  expect(m.largeurPage).toBeGreaterThan(m.largeurEcran);
  expect(m.petitesZones).toEqual([expect.stringContaining("30 × 30 px")]);
  expect(m.petitsTextes).toEqual([expect.stringContaining("12 px")]);
  const axe = await new AxeBuilder({ page }).withRules(["color-contrast"]).analyze();
  expect(axe.violations.map((v) => v.id)).toEqual(["color-contrast"]);
});

test("BNF-10 et BNF-11 : écrans du parcours de réservation, non connecté puis connecté", async ({ page }) => {
  await page.goto("/");
  await verifier(page, "accueil");

  await page.goto("/reserver");
  await verifier(page, "écran 1, prestations");

  await page.goto(`/reserver/creneaux?prestation=${SEED.coupeHomme}`);
  await expect(page.getByRole("link", { name: /^\d{2}:\d{2}$/ }).first()).toBeVisible();
  await verifier(page, "écran 2, créneaux");

  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  await page.goto(
    `/reserver/confirmation?${new URLSearchParams({ prestation: SEED.coupeHomme, debut, coiffeur: SEED.amira })}`,
  );
  await verifier(page, "écran 3, confirmation (non connecté)");

  await page.getByLabel("Nom").fill("Client Écrans");
  await page.getByLabel("E-mail").fill(emailUnique("ecrans"));
  await page.getByRole("button", { name: "Recevoir le code" }).click();
  await expect(page.getByLabel("Code à 6 chiffres")).toBeVisible();
  await verifier(page, "écran 3, saisie du code");
});

test("BNF-10 et BNF-11 : réservation confirmée, mes réservations, annulation", async ({ page }) => {
  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  await page.goto(
    `/reserver/confirmation?${new URLSearchParams({ prestation: SEED.coupeHomme, debut, coiffeur: SEED.amira })}`,
  );
  await seConnecter(page, "Client Écrans", emailUnique("ecrans-connecte"));
  await verifier(page, "écran 3, confirmation (connecté)");

  await page.getByRole("button", { name: "Confirmer la réservation" }).click();
  await expect(page.getByRole("heading", { name: "Réservation confirmée" })).toBeVisible();
  await verifier(page, "réservation confirmée");

  await page.getByRole("link", { name: "Voir mes réservations" }).click();
  await expect(page.getByRole("heading", { name: "Coupe homme" })).toBeVisible();
  await verifier(page, "mes réservations (connecté)");

  await page.getByRole("button", { name: "Annuler la réservation" }).click();
  await expect(page.getByRole("button", { name: "Oui, annuler" })).toBeVisible();
  await verifier(page, "mes réservations, demande d'annulation");
});

test("BNF-10 et BNF-11 : mes réservations sans compte, page de la charte", async ({ page }) => {
  await page.goto("/mes-reservations");
  await verifier(page, "mes réservations (non connecté)");

  await page.goto("/charte");
  await verifier(page, "charte graphique");
});
