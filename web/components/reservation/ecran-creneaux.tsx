"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useId, useMemo, useState } from "react";
import { BandeJours } from "@/components/reservation/bande-jours";
import { ListeCreneaux } from "@/components/reservation/liste-creneaux";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { focus } from "@/components/ui/styles";
import { coiffeursCompetents, type Catalogue } from "@/lib/catalogue";
import {
  grouperParJour,
  JOURS_AFFICHES,
  lireCreneaux,
  periode,
  type Creneau,
  type Jour,
} from "@/lib/creneaux";
import { formatDuree, formatPrix } from "@/lib/format";
import { prendrePrechargement } from "@/lib/precharger-creneaux";

// Résultat d'une lecture, rattaché à sa demande (prestation, coiffeur, essai) :
// tant que la clé ne correspond pas à la demande en cours, on affiche le
// chargement.
type Resultat = { cle: string } & (
  | { erreur: true }
  | { erreur: false; du: string; creneaux: Creneau[] }
);

// Écran 2 : bande des jours, créneaux du jour choisi (par défaut, le premier
// jour disponible), filtre coiffeur (« Peu importe » par défaut, BNF-9). Le catalogue arrive avec la page statique ; seuls les
// créneaux sont lus au chargement, sans connexion (BF-C1).
export function EcranCreneaux({ catalogue }: { catalogue: Catalogue }) {
  const params = useSearchParams();
  const prestationId = params.get("prestation") ?? "";
  const prestation = catalogue.prestations.find((p) => p.id === prestationId);
  // Filtre repris de l'URL (retour depuis l'écran 3), s'il est valable.
  const [coiffeurId, setCoiffeurId] = useState(() => {
    const demande = params.get("coiffeur") ?? "";
    return coiffeursCompetents(catalogue, prestationId).some((c) => c.id === demande) ? demande : "";
  });
  const [essai, setEssai] = useState(0);
  const [resultat, setResultat] = useState<Resultat | null>(null);
  const idFiltre = useId();
  // Retour de l'écran 3 après un refus (#51) : liste relue, message en tête.
  const pris = params.get("pris") === "1";
  const cle = `${prestationId}|${coiffeurId}|${essai}|${pris}`;
  // Recalculés seulement à chaque nouvelle lecture : le jour choisi tient tant
  // que la lecture ne change pas.
  const jours = useMemo(
    () =>
      resultat && !resultat.erreur
        ? grouperParJour(resultat.creneaux, catalogue.fuseau, resultat.du)
        : [],
    [resultat, catalogue.fuseau],
  );

  useEffect(() => {
    if (!prestation) return;
    const abandon = new AbortController();
    const { du, au } = periode(new Date(), catalogue.fuseau);

    const demande = { prestationId: prestation.id, du, au, coiffeurId: coiffeurId || undefined };
    // Après un refus, jamais de lecture anticipée : la liste vient de la base.
    const lecture =
      (demande.coiffeurId || pris ? undefined : prendrePrechargement(demande)) ??
      lireCreneaux(demande, abandon.signal);

    lecture.then(
      (creneaux) => setResultat({ cle, erreur: false, du, creneaux }),
      () => {
        if (!abandon.signal.aborted) setResultat({ cle, erreur: true });
      },
    );

    return () => abandon.abort();
  }, [cle, prestation, coiffeurId, pris, catalogue.fuseau]);

  if (!prestation) {
    return (
      <div className="flex flex-col items-start gap-6">
        <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
          Prestation introuvable
        </h1>
        <BoutonLien href="/reserver">Voir les prestations</BoutonLien>
      </div>
    );
  }

  const coiffeurs = coiffeursCompetents(catalogue, prestation.id);

  return (
    <div className="flex flex-col gap-6">
      <Link
        href="/reserver"
        className={`inline-flex min-h-11 items-center self-start rounded-base text-base font-semibold text-accent underline ${focus}`}
      >
        ← Changer de prestation
      </Link>

      {pris && (
        <p role="alert" className="text-base font-semibold text-erreur">
          Ce créneau vient d&apos;être pris. Choisissez-en un autre.
        </p>
      )}

      <div className="flex flex-col gap-1">
        <h1 className="font-titre text-2xl font-medium break-words text-texte sm:text-3xl">
          {prestation.nom}
        </h1>
        <p className="text-base text-texte-secondaire tabular-nums">
          {formatDuree(prestation.dureeMinutes)} · {formatPrix(prestation.prix)}
        </p>
      </div>

      <div className="flex flex-col gap-2">
        <label htmlFor={idFiltre} className="text-base font-semibold text-texte">
          Coiffeur
        </label>
        <select
          id={idFiltre}
          value={coiffeurId}
          onChange={(evenement) => setCoiffeurId(evenement.target.value)}
          className={`h-12 rounded-base border border-bordure bg-surface px-4 text-base text-texte ${focus}`}
        >
          <option value="">Peu importe</option>
          {coiffeurs.map((coiffeur) => (
            <option key={coiffeur.id} value={coiffeur.id}>
              {coiffeur.nom}
            </option>
          ))}
        </select>
      </div>

      {!resultat || resultat.cle !== cle ? (
        <p role="status" className="text-base text-texte-secondaire">
          Chargement des créneaux…
        </p>
      ) : resultat.erreur ? (
        <div className="flex flex-col items-start gap-3">
          <p role="alert" className="text-base text-erreur">
            Impossible de charger les créneaux. Vérifiez votre connexion.
          </p>
          <Bouton variante="secondaire" onClick={() => setEssai((n) => n + 1)}>
            Réessayer
          </Bouton>
        </div>
      ) : (
        <Creneaux
          jours={jours}
          prestationId={prestation.id}
          coiffeurId={coiffeurId || undefined}
        />
      )}
    </div>
  );
}

// Jour affiché : celui choisi dans la bande, sinon le premier jour disponible.
// Les jours sont recalculés à chaque lecture (autre coiffeur, nouvel essai) :
// le premier jour disponible reprend alors la main.
function Creneaux({
  jours,
  prestationId,
  coiffeurId,
}: {
  jours: Jour[];
  prestationId: string;
  coiffeurId?: string;
}) {
  const [choix, setChoix] = useState<{ jours: Jour[]; cle: string } | null>(null);
  const disponibles = jours.filter((jour) => jour.heures.length > 0);

  if (disponibles.length === 0) {
    return (
      <p role="status" className="text-base text-texte">
        Aucun créneau libre sur les {JOURS_AFFICHES} prochains jours
        {coiffeurId ? " avec ce coiffeur. Essayez « Peu importe »." : "."}
      </p>
    );
  }

  const jour =
    (choix?.jours === jours && disponibles.find((j) => j.cle === choix.cle)) || disponibles[0];

  return (
    <div className="flex flex-col gap-6">
      <BandeJours
        jours={jours}
        choisi={jour.cle}
        onChoisir={(cle) => setChoix({ jours, cle })}
      />
      <ListeCreneaux jour={jour} prestationId={prestationId} coiffeurId={coiffeurId} />
    </div>
  );
}
