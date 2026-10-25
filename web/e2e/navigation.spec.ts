import { expect, test, type Page } from "@playwright/test";
import { SEED } from "./outils";

// Issue #53 : navigation du site client. « Retour » à chaque étape, retour du
// navigateur, barre d'onglets en bas sous 768 px, liens d'en-tête au-delà.

const onglets = (page: Page) => page.getByRole("navigation", { name: "Navigation principale" });

test("téléphone (360 px) : barre d'onglets en bas, onglet courant, rien de masqué dessous", async ({ page }) => {
  await page.goto("/reserver");
  const barre = onglets(page);
  await expect(barre).toHaveCount(1); // l'en-tête d'ordinateur est masqué
  await expect(barre.getByRole("link")).toHaveText(["Accueil", "Réserver", "Mes réservations"]);
  await expect(barre.getByRole("link", { name: "Réserver" })).toHaveAttribute("aria-current", "page");

  // Barre collée au bas de l'écran.
  const boite = (await barre.boundingBox())!;
  expect(Math.round(boite.y + boite.height)).toBe(800);

  // En bas de page, la dernière prestation reste entièrement au-dessus de la barre.
  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  const derniere = (await page.getByRole("main").getByRole("link").last().boundingBox())!;
  expect(derniere.y + derniere.height).toBeLessThanOrEqual(boite.y);

  await barre.getByRole("link", { name: "Mes réservations" }).click();
  await expect(page).toHaveURL(/\/mes-reservations$/);
  await expect(onglets(page).getByRole("link", { name: "Mes réservations" })).toHaveAttribute("aria-current", "page");
});

test.describe("ordinateur (1366 px)", () => {
  test.use({ viewport: { width: 1366, height: 768 }, isMobile: false, hasTouch: false });

  test("liens dans l'en-tête, pas de barre d'onglets", async ({ page }) => {
    await page.goto("/");
    const nav = onglets(page);
    await expect(nav).toHaveCount(1); // la barre d'onglets est masquée
    expect((await nav.boundingBox())!.y).toBeLessThan(100); // en haut de page
    await expect(nav.getByRole("link")).toHaveText(["Accueil", "Réserver", "Mes réservations"]);
    await expect(nav.getByRole("link", { name: "Accueil" })).toHaveAttribute("aria-current", "page");
    await nav.getByRole("link", { name: "Réserver" }).click();
    await expect(page).toHaveURL(/\/reserver$/);
    await expect(onglets(page).getByRole("link", { name: "Réserver" })).toHaveAttribute("aria-current", "page");
  });
});

test("« Retour » à chaque étape, puis retour du navigateur", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("main").getByRole("link", { name: "Réserver" }).click();
  await expect(page).toHaveURL(/\/reserver$/);
  await page.getByRole("link", { name: "Retour à l'accueil" }).click();
  await expect(page).toHaveURL(/\/$/);

  // Accueil → prestations → créneaux (Amira) → confirmation.
  await page.getByRole("main").getByRole("link", { name: "Réserver" }).click();
  await page.getByRole("link", { name: /Coupe homme/ }).click();
  await page.getByLabel("Coiffeur").selectOption(SEED.amira);
  await page.getByRole("link", { name: /^\d{2}:\d{2}$/ }).first().click();
  await expect(page).toHaveURL(/\/reserver\/confirmation\?/);

  // « Retour » ramène à l'étape précédente, sans perdre le coiffeur choisi.
  await page.getByRole("link", { name: "Retour aux créneaux" }).click();
  await expect(page).toHaveURL(/\/reserver\/creneaux\?/);
  await expect(page.getByLabel("Coiffeur")).toHaveValue(SEED.amira);
  await page.getByRole("link", { name: "Retour aux prestations" }).click();
  await expect(page).toHaveURL(/\/reserver$/);

  // Retour du navigateur : on remonte l'historique, écran par écran.
  await page.goBack();
  await expect(page).toHaveURL(/\/reserver\/creneaux\?/);
  await page.goBack();
  await expect(page).toHaveURL(/\/reserver\/confirmation\?/);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Confirmer la réservation");
});

test("écran ouvert directement (lien partagé) : « Retour » marche quand même", async ({ page }) => {
  await page.goto(`/reserver/creneaux?prestation=${SEED.coupeHomme}`);
  await page.getByRole("link", { name: "Retour aux prestations" }).click();
  await expect(page).toHaveURL(/\/reserver$/);
  await page.getByRole("link", { name: "Retour à l'accueil" }).click();
  await expect(page).toHaveURL(/\/$/);
});
