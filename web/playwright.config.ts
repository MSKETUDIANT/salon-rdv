import { execSync } from "node:child_process";
import { defineConfig } from "@playwright/test";

// Tests de bout en bout (e2e/) : site construit et servi sur la base LOCALE
// (`supabase start`), jamais sur la base distante. Codes de connexion lus dans
// Mailpit. Navigateur : le Chrome installé (channel "chrome"), rien à
// télécharger.

function baseLocale(): Record<string, string> {
  const sortie = execSync("supabase status -o env", {
    cwd: "..",
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  });
  return Object.fromEntries(
    sortie
      .split(/\r?\n/)
      .filter((ligne) => /^[A-Z_]+=/.test(ligne))
      .map((ligne) => {
        const i = ligne.indexOf("=");
        return [ligne.slice(0, i), ligne.slice(i + 1).replace(/^"|"$/g, "")];
      }),
  );
}

const local = baseLocale();
const port = 3200;

// Lus par e2e/outils.ts (chaque processus de test recharge cette config).
process.env.E2E_API_URL = local.API_URL;
process.env.E2E_ANON_KEY = local.ANON_KEY;
process.env.E2E_SERVICE_ROLE_KEY = local.SERVICE_ROLE_KEY;
process.env.E2E_MAILPIT_URL = local.MAILPIT_URL;

export default defineConfig({
  testDir: "e2e",
  // Une seule base partagée : les tests s'enchaînent.
  workers: 1,
  timeout: 90_000,
  reporter: "list",
  use: {
    baseURL: `http://localhost:${port}`,
    channel: "chrome",
    viewport: { width: 360, height: 800 },
    isMobile: true,
    hasTouch: true,
    locale: "fr-FR",
  },
  projects: [
    { name: "clair" },
    // Mode sombre (issue 21) : les écrans et leurs états repassent l'audit
    // BNF-10/11 (axe-core, contrastes) avec le réglage sombre du téléphone.
    { name: "sombre", testMatch: /bnf-10-11-ecrans\.spec\.ts/, use: { colorScheme: "dark" } },
  ],
  webServer: {
    command: `npm run build && npx next start -p ${port}`,
    url: `http://localhost:${port}/reserver`,
    timeout: 300_000,
    reuseExistingServer: false,
    env: {
      NEXT_PUBLIC_SUPABASE_URL: local.API_URL,
      NEXT_PUBLIC_SUPABASE_ANON_KEY: local.ANON_KEY,
      // Salon du seed (supabase/seed.sql).
      NEXT_PUBLIC_SALON_ID: "11111111-1111-1111-1111-111111111111",
    },
  },
});
