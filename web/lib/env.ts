// Variables publiques, inlinées au build. Toujours écrire process.env.NEXT_PUBLIC_…
// en entier : Next.js ne remplace que les accès littéraux.

export function exiger(nom: string, valeur: string | undefined): string {
  if (!valeur) {
    throw new Error(`Variable d'environnement manquante : ${nom} (voir web/.env.example)`);
  }
  return valeur;
}

// Getters : l'erreur n'est levée qu'à l'usage, pas à l'import.
export const env = {
  get supabaseUrl() {
    return exiger("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL);
  },
  get supabaseAnonKey() {
    return exiger("NEXT_PUBLIC_SUPABASE_ANON_KEY", process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  },
  get salonId() {
    return exiger("NEXT_PUBLIC_SALON_ID", process.env.NEXT_PUBLIC_SALON_ID);
  },
};
