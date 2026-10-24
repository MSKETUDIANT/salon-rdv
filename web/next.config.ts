import type { NextConfig } from "next";
import { env } from "./lib/env";

const nextConfig: NextConfig = {
  // Créneaux (#5) lus sur la même origine que le site : ni connexion de plus ni
  // requête CORS préalable en 3G (BNF-5). La requête part telle quelle vers
  // PostgREST, en-tête apikey compris.
  async rewrites() {
    return [
      {
        source: "/api/creneaux",
        destination: `${env.supabaseUrl}/rest/v1/rpc/creneaux_disponibles`,
      },
    ];
  },
  /* config options here */
  cacheComponents: true,
  partialPrefetching: true,
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
