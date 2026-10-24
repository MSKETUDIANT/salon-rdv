import { expect, test, type Page } from "@playwright/test";
import { creneauLibre, emailUnique, reservationsA, SEED, seConnecter } from "./outils";

// Issue #6 : parcours de réservation de bout en bout, sur la base locale.

test("parcours complet en 3 écrans, connexion seulement à l'écran 3, réservation enregistrée", async ({
  page,
}, testInfo) => {
  // Écrans traversés (navigations, y compris côté client), accueil compris.
  const ecrans: string[] = [];
  page.on("framenavigated", (frame) => {
    if (frame !== page.mainFrame()) return;
    const chemin = new URL(frame.url()).pathname;
    if (ecrans.at(-1) !== chemin) ecrans.push(chemin);
  });

  await page.goto("/");
  const debut = Date.now();
  await page.getByRole("link", { name: "Réserver" }).click();

  // Écran 1 : aucune connexion demandée.
  await page.getByRole("link", { name: /Coupe homme/ }).click();

  // Écran 2 : aucune connexion demandée ; on prend la première heure.
  const heure = page.getByRole("link", { name: /^\d{2}:\d{2}$/ }).first();
  await expect(heure).toBeVisible();
  await expect(page.getByLabel("E-mail")).toHaveCount(0);
  const lien = new URL((await heure.getAttribute("href"))!, "http://x");
  await heure.click();

  // Écran 3 : « Confirmer » sans connexion indique ce qui manque.
  await expect(page.getByRole("heading", { name: "Confirmer la réservation" })).toBeVisible();
  await page.getByRole("button", { name: "Confirmer la réservation" }).click();
  await expect(page.getByText(/Pour confirmer, indiquez votre nom et votre e-mail/)).toBeVisible();

  // Connexion sans quitter l'écran ; le créneau choisi est conservé.
  const email = emailUnique("parcours");
  await seConnecter(page, "Client Parcours", email);
  await expect(page).toHaveURL(/\/reserver\/confirmation\?/);
  expect(new URL(page.url()).searchParams.get("debut")).toBe(lien.searchParams.get("debut"));

  await page.getByRole("button", { name: "Confirmer la réservation" }).click();
  await expect(page.getByRole("heading", { name: "Réservation confirmée" })).toBeVisible();
  const duree = ((Date.now() - debut) / 1000).toFixed(1);
  testInfo.annotations.push({ type: "BNF-4 (indicatif, automate)", description: `${duree} s` });
  console.log(`Parcours complet (automate, accueil → confirmée) : ${duree} s`);

  // BNF-9 : 3 écrans hors accueil et hors authentification (faite sur l'écran 3).
  expect(ecrans).toEqual(["/", "/reserver", "/reserver/creneaux", "/reserver/confirmation"]);

  // BF-C5 : la réservation est en base, rattachée au client connecté.
  const enBase = await reservationsA(lien.searchParams.get("debut")!);
  expect(enBase.filter((r) => r.client.email === email)).toEqual([
    expect.objectContaining({ statut: "confirmee" }),
  ]);
});

test("BNF-1 : deux validations simultanées du même créneau, une seule réussit", async ({
  browser,
}) => {
  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  const url = `/reserver/confirmation?${new URLSearchParams({
    prestation: SEED.coupeHomme,
    debut,
    coiffeur: SEED.amira,
  })}`;

  // Deux clients, chacun dans son navigateur, connectés sur le même créneau.
  const clients: Page[] = [];
  for (const nom of ["un", "deux"]) {
    const contexte = await browser.newContext({
      viewport: { width: 360, height: 800 },
      isMobile: true,
      hasTouch: true,
      locale: "fr-FR",
    });
    const page = await contexte.newPage();
    await page.goto(url);
    await seConnecter(page, `Client ${nom}`, emailUnique(`simultane-${nom}`));
    clients.push(page);
  }

  // Les deux valident en même temps.
  await Promise.all(
    clients.map((page) => page.getByRole("button", { name: "Confirmer la réservation" }).click()),
  );
  const issues = await Promise.all(
    clients.map(async (page) => {
      const confirmee = page.getByRole("heading", { name: "Réservation confirmée" });
      const prise = page.getByText("Ce créneau vient d'être pris. Choisissez-en un autre.");
      await expect(confirmee.or(prise)).toBeVisible();
      return (await confirmee.isVisible()) ? "confirmee" : "prise";
    }),
  );
  expect([...issues].sort()).toEqual(["confirmee", "prise"]);

  // En base : une seule réservation sur ce créneau chez Amira.
  const enBase = (await reservationsA(debut)).filter((r) => r.coiffeur_id === SEED.amira);
  expect(enBase).toHaveLength(1);

  // Le perdant revient aux créneaux sans perdre la prestation ni le coiffeur.
  const perdant = clients[issues.indexOf("prise")];
  await perdant.getByRole("link", { name: "Choisir un autre créneau" }).click();
  await expect(perdant).toHaveURL(/\/reserver\/creneaux\?/);
  await expect(perdant.getByRole("heading", { level: 1 })).toHaveText("Coupe homme");
  await expect(perdant.getByLabel("Coiffeur")).toHaveValue(SEED.amira);
});
