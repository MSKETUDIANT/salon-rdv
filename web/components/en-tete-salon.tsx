export function EnTeteSalon({ nom }: { nom: string }) {
  return (
    <header>
      <p className="text-sm font-medium uppercase tracking-wide text-zinc-500">
        Réservation en ligne
      </p>
      <h1 className="mt-2 text-3xl font-semibold break-words text-foreground sm:text-5xl">
        {nom}
      </h1>
      <p className="mt-4 text-base text-zinc-600 dark:text-zinc-400">
        Bientôt : choisissez une prestation, un coiffeur et un créneau, sans
        application à installer.
      </p>
    </header>
  );
}
