// Prix en dinars tunisiens : sans décimales quand les millimes sont à zéro
// (« 35 DT »), sinon avec les 3 décimales (« 12,500 DT »).
const formatDinar = new Intl.NumberFormat("fr-TN", { style: "currency", currency: "TND" });
const formatDinarRond = new Intl.NumberFormat("fr-TN", {
  style: "currency",
  currency: "TND",
  maximumFractionDigits: 0,
});

export function formatPrix(prix: number): string {
  const sansMillimes = Math.round(prix * 1000) % 1000 === 0;
  return (sansMillimes ? formatDinarRond : formatDinar).format(prix);
}

// Durée lisible : « 30 min », « 1 h », « 1 h 30 ».
export function formatDuree(minutes: number): string {
  const heures = Math.floor(minutes / 60);
  const reste = minutes % 60;
  if (heures === 0) return `${reste} min`;
  return reste === 0 ? `${heures} h` : `${heures} h ${String(reste).padStart(2, "0")}`;
}
