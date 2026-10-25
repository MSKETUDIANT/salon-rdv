import { expect, test } from "@playwright/test";
import { emailUnique, reservationsA, seConnecter } from "./outils";

// Issue #12, BNF-7 (portabilité), partie automatique : le parcours complet de
// réservation dans Chrome sur ordinateur (écran 1366 × 768, souris, sans
// émulation mobile). La partie Android et le navigateur de Sparta sont
// vérifiés à la main (docs/resultats-bnf.md).

test.use({ viewport: { width: 1366, height: 768 }, isMobile: false, hasTouch: false });

test("BNF-7 : réservation complète dans Chrome sur ordinateur", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("link", { name: "Réserver" }).click();
  await page.getByRole("link", { name: /Coupe homme/ }).click();

  const heure = page.getByRole("link", { name: /^\d{2}:\d{2}$/ }).first();
  await expect(heure).toBeVisible();
  const debut = new URL((await heure.getAttribute("href"))!, "http://x").searchParams.get("debut")!;
  await heure.click();

  const email = emailUnique("ordinateur");
  await seConnecter(page, "Client Ordinateur", email);
  await page.getByRole("button", { name: "Confirmer la réservation" }).click();
  await expect(page.getByRole("heading", { name: "Réservation confirmée" })).toBeVisible();

  // Pas de défilement horizontal non plus en grand écran.
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(1366);

  const enBase = await reservationsA(debut);
  expect(enBase.filter((r) => r.client.email === email)).toEqual([
    expect.objectContaining({ statut: "confirmee" }),
  ]);
});
