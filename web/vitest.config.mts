import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: { "@": fileURLToPath(new URL("./", import.meta.url)) },
  },
  test: {
    // Tests de composants : `// @vitest-environment jsdom` en tête de fichier.
    environment: "node",
    include: ["**/*.test.{ts,tsx}"],
    exclude: ["node_modules/**", ".next/**"],
    // Rapport de couverture (BNF-6, `npm run test:couverture`) : code du site,
    // sans les tests ni les types générés de la base.
    coverage: {
      provider: "v8",
      include: ["app/**", "components/**", "lib/**"],
      exclude: ["**/*.test.{ts,tsx}", "lib/database.types.ts"],
      reporter: ["text-summary", "text", "json-summary"],
      reportsDirectory: "coverage",
    },
  },
});
