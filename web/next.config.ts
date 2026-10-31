import type { NextConfig } from "next";
import { env } from "./lib/env";

// Photo du salon (#117) : seuls les fichiers publics de l'espace « salons » du
// projet Supabase sont optimisés par next/image ; toute autre adresse est
// refusée. En local, Supabase répond sur 127.0.0.1 : l'optimisation d'une
// adresse locale n'est permise que dans ce cas.
const supabase = new URL(env.supabaseUrl);
const supabaseLocal = ["127.0.0.1", "localhost"].includes(supabase.hostname);

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [new URL("/storage/v1/object/public/salons/**", supabase)],
    dangerouslyAllowLocalIP: supabaseLocal,
  },
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
