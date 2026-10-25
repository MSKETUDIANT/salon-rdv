import { expect, test } from "@playwright/test";
import { creneauLibre, emailUnique, reservationsA, SEED } from "./outils";

// Issue #12, BNF-1 (fiabilité) : N clients réservent le même créneau au même
// moment, par l'API (fonction reserver(), comme le site), sur la base locale.
// Attendu : une seule réservation, tous les autres reçoivent PT409.

const N = 20;

const api = () => process.env.E2E_API_URL!;
const anon = () => process.env.E2E_ANON_KEY!;
const service = () => process.env.E2E_SERVICE_ROLE_KEY!;

// Compte client confirmé (clé service, base locale uniquement), puis jeton de
// connexion par mot de passe.
async function nouveauClient(i: number): Promise<string> {
  const email = emailUnique(`charge-${i}`);
  const motDePasse = `charge-${Date.now()}-${i}`;
  const creation = await fetch(`${api()}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: service(),
      Authorization: `Bearer ${service()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email,
      password: motDePasse,
      email_confirm: true,
      user_metadata: { nom: `Client charge ${i}` },
    }),
  });
  expect(creation.ok, await creation.clone().text()).toBe(true);
  const connexion = await fetch(`${api()}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: anon(), "Content-Type": "application/json" },
    body: JSON.stringify({ email, password: motDePasse }),
  });
  expect(connexion.ok).toBe(true);
  return ((await connexion.json()) as { access_token: string }).access_token;
}

test(`BNF-1 : ${N} réservations simultanées du même créneau, une seule réussit`, async ({}, testInfo) => {
  const debut = await creneauLibre(SEED.coupeHomme, SEED.amira);
  const jetons = await Promise.all(Array.from({ length: N }, (_, i) => nouveauClient(i)));

  // Les N appels partent ensemble (aucun n'attend un autre).
  const depart = Date.now();
  const reponses = await Promise.all(
    jetons.map((jeton) =>
      fetch(`${api()}/rest/v1/rpc/reserver`, {
        method: "POST",
        headers: {
          apikey: anon(),
          Authorization: `Bearer ${jeton}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ p_prestation: SEED.coupeHomme, p_debut: debut, p_coiffeur: SEED.amira }),
      }).then(async (r) => ({ statut: r.status, corps: await r.json() })),
    ),
  );
  const duree = Date.now() - depart;

  const reussites = reponses.filter((r) => r.statut === 200);
  const codes = reponses.filter((r) => r.statut !== 200).map((r) => r.corps.code);
  const resume = `${reussites.length} réussite, ${codes.length} refus (${[...new Set(codes)].join(", ")}), ${duree} ms`;
  testInfo.annotations.push({ type: "BNF-1", description: resume });
  console.log(`BNF-1, ${N} appels simultanés : ${resume}`);

  expect(reussites).toHaveLength(1);
  expect(codes).toEqual(Array(N - 1).fill("PT409"));

  // En base : une seule réservation non annulée sur ce créneau chez Amira.
  const enBase = (await reservationsA(debut)).filter((r) => r.coiffeur_id === SEED.amira);
  expect(enBase).toHaveLength(1);
});
