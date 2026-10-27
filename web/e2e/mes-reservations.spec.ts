import { expect, test } from "@playwright/test";
import {
  apiClient,
  attendreDelaiEntreCodes,
  creneauLibre,
  creneauPropose,
  emailUnique,
  jetonClient,
  lireCode,
  reservationsA,
  SEED,
  seConnecter,
  statutsDuClient,
} from "./outils";

// Issue #7 : consulter et annuler sa réservation (BF-C6, BNF-3), sur la base
// locale.

const SALON = "11111111-1111-1111-1111-111111111111";

test("réserver, retrouver sa réservation, l'annuler : le créneau est de nouveau proposé", async ({
  page,
}) => {
  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  const email = emailUnique("mes-reservations");
  await page.goto(
    `/reserver/confirmation?${new URLSearchParams({ prestation: SEED.coupeHomme, debut, coiffeur: SEED.amira })}`,
  );
  await seConnecter(page, "Client Annulation", email);
  await page.getByRole("button", { name: "Confirmer la réservation" }).click();
  await expect(page.getByRole("heading", { name: "Réservation confirmée" })).toBeVisible();
  expect(await creneauPropose(SEED.coupeHomme, SEED.amira, debut)).toBe(false);

  // Depuis la confirmation : la réservation est dans « À venir ».
  await page.getByRole("link", { name: "Voir mes réservations" }).click();
  await expect(page).toHaveURL(/\/mes-reservations$/);
  const aVenir = page.getByRole("region", { name: "À venir" });
  await expect(aVenir.getByRole("heading", { name: "Coupe homme" })).toBeVisible();
  await expect(aVenir.getByText("Amira")).toBeVisible();
  await expect(aVenir.getByText("Confirmée")).toBeVisible();

  // Annuler demande confirmation.
  await aVenir.getByRole("button", { name: "Annuler la réservation" }).click();
  await aVenir.getByRole("button", { name: "Oui, annuler" }).click();
  await expect(page.getByRole("status")).toHaveText(/annulée\.$/);
  await expect(aVenir.getByText("Aucune réservation à venir.")).toBeVisible();
  const historique = page.getByRole("region", { name: "Passées et annulées" });
  await expect(historique.getByText("Annulée", { exact: true })).toBeVisible();
  await expect(historique.getByRole("button", { name: "Annuler la réservation" })).toHaveCount(0);

  // En base : statut annulé, la ligne reste ; le créneau est de nouveau proposé.
  expect(await statutsDuClient(debut, email)).toEqual(["annulee"]);
  expect(await creneauPropose(SEED.coupeHomme, SEED.amira, debut)).toBe(true);

  // Après déconnexion : reconnexion avec l'e-mail seul, la réservation est là.
  const premierCode = await lireCode(email);
  await page.getByRole("button", { name: "Changer de compte" }).click();
  await expect(page.getByLabel("Nom")).toHaveCount(0);
  await page.getByLabel("E-mail").fill(email);
  await attendreDelaiEntreCodes(email);
  await page.getByRole("button", { name: "Recevoir le code" }).click();
  await page.getByLabel("Code à 6 chiffres").fill(await lireCode(email, premierCode));
  await page.getByRole("button", { name: "Valider le code" }).click();
  await expect(historique.getByRole("heading", { name: "Coupe homme" })).toBeVisible();
});

test("e-mail sans compte : pas de code envoyé, message clair", async ({ page }) => {
  await page.goto("/mes-reservations");
  await page.getByLabel("E-mail").fill(emailUnique("sans-compte"));
  await page.getByRole("button", { name: "Recevoir le code" }).click();
  await expect(page.getByText(/Aucun compte avec cette adresse/)).toBeVisible();
});

test("BNF-3 : par l'API, un client ne lit ni n'annule la réservation d'un autre", async () => {
  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  const jetonA = await jetonClient(emailUnique("api-a"), "Client A");
  const jetonB = await jetonClient(emailUnique("api-b"), "Client B");

  const reservation = await apiClient(jetonA, "rpc/reserver", {
    method: "POST",
    body: JSON.stringify({ p_prestation: SEED.coupeHomme, p_debut: debut, p_coiffeur: SEED.amira }),
  });
  expect(reservation.status).toBe(200);
  const [{ id }] = await reservation.json();

  // Lecture : A la voit, B ne la voit pas.
  const lire = (jeton: string) =>
    apiClient(jeton, "rpc/mes_reservations", {
      method: "POST",
      body: JSON.stringify({ p_salon: SALON }),
    }).then((r) => r.json());
  expect((await lire(jetonA)).map((r: { id: string }) => r.id)).toEqual([id]);
  expect(await lire(jetonB)).toEqual([]);

  // Annulation par la fonction : refusée (PT404 → 404), comme sans compte (401).
  const annuler = (jeton: string | null) =>
    apiClient(jeton, "rpc/annuler_reservation", {
      method: "POST",
      body: JSON.stringify({ p_reservation: id }),
    });
  expect((await annuler(jetonB)).status).toBe(404);
  expect((await annuler(null)).status).toBe(401);

  // Modification directe de la table : aucune ligne touchée.
  const modification = await apiClient(jetonB, `reservations?id=eq.${id}`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ statut: "annulee" }),
  });
  expect(await modification.json()).toEqual([]);

  // La réservation de A est intacte.
  const enBase = (await reservationsA(debut)).filter((r) => r.coiffeur_id === SEED.amira);
  expect(enBase).toEqual([expect.objectContaining({ statut: "confirmee" })]);
});
