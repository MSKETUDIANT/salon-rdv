import { expect, test, type Page } from "@playwright/test";
import { contexteEchec, creneauLibre, emailUnique, reservationsA, SEED, seConnecter } from "./outils";

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
  await page.getByRole("main").getByRole("link", { name: "Réserver" }).click();

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

  // Tous les messages affichés à chacun, du clic à la fin (#51).
  for (const page of clients) {
    await page.evaluate(() => {
      const vus: string[] = [];
      (window as unknown as { __messages: string[] }).__messages = vus;
      new MutationObserver(() => {
        for (const el of document.querySelectorAll('[role="alert"]')) {
          const texte = (el.textContent ?? "").trim();
          if (texte && (el as HTMLElement).offsetParent !== null && !vus.includes(texte)) vus.push(texte);
        }
      }).observe(document.body, { subtree: true, childList: true, characterData: true });
    });
  }

  // Les deux valident en même temps.
  await Promise.all(
    clients.map((page) => page.getByRole("button", { name: "Confirmer la réservation" }).click()),
  );
  // Le gagnant voit la confirmation ; le perdant est renvoyé tout seul sur
  // l'écran 2 (#51). Jamais d'écran sans l'un ou l'autre.
  const issues = await Promise.all(
    clients.map(async (page) => {
      const confirmee = page.getByRole("heading", { name: "Réservation confirmée" });
      const prise = page.getByRole("alert").filter({ hasText: "Ce créneau vient d'être pris. Choisissez-en un autre." });
      await expect(confirmee.or(prise)).toBeVisible();
      return (await confirmee.isVisible()) ? "confirmee" : "prise";
    }),
  );
  expect([...issues].sort()).toEqual(["confirmee", "prise"]);

  // En base : une seule réservation sur ce créneau chez Amira.
  const surLeCreneau = await reservationsA(debut);
  const enBase = surLeCreneau.filter((r) => r.coiffeur_id === SEED.amira);
  const pages = clients.map((page, i) => ({ issue: issues[i], url: page.url() }));
  expect(enBase, contexteEchec({ debut, pages, surLeCreneau })).toHaveLength(1);

  // Le perdant est sur l'écran 2, prestation et coiffeur conservés, liste
  // relue : des heures proposées, mais plus celle qui vient d'être prise.
  const perdant = clients[issues.indexOf("prise")];
  await expect(perdant).toHaveURL(/\/reserver\/creneaux\?.*pris=1/);

  // Le perdant n'a vu qu'un seul message, celui de la liste : ni « Réessayez »,
  // ni étape intermédiaire sur l'écran 3.
  const messages = await perdant.evaluate(() => (window as unknown as { __messages: string[] }).__messages);
  expect(messages).toEqual(["Ce créneau vient d'être pris. Choisissez-en un autre."]);
  await expect(perdant.getByRole("heading", { level: 1 })).toHaveText("Coupe homme");
  await expect(perdant.getByLabel("Coiffeur")).toHaveValue(SEED.amira);
  const heures = perdant.getByRole("link", { name: /^\d{2}:\d{2}$/ });
  await expect(heures.first()).toBeVisible();
  const liens = await heures.evaluateAll((elements) => elements.map((e) => e.getAttribute("href") ?? ""));
  expect(liens.some((href) => href.includes(encodeURIComponent(debut)))).toBe(false);

  // Le retour du navigateur ne ramène pas sur le créneau perdu.
  await perdant.goBack();
  await expect(perdant).not.toHaveURL(new RegExp(encodeURIComponent(debut).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
});
