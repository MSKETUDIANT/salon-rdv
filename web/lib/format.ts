// Prix en dinars tunisiens, 3 décimales (millimes) : « 35,000 DT ».
const formatDinar = new Intl.NumberFormat("fr-TN", { style: "currency", currency: "TND" });

export function formatPrix(prix: number): string {
  return formatDinar.format(prix);
}

// Durée lisible : « 30 min », « 1 h », « 1 h 30 ».
export function formatDuree(minutes: number): string {
  const heures = Math.floor(minutes / 60);
  const reste = minutes % 60;
  if (heures === 0) return `${reste} min`;
  return reste === 0 ? `${heures} h` : `${heures} h ${String(reste).padStart(2, "0")}`;
}
