"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useId, useState } from "react";
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
} from "@/lib/creneaux";
import { formatDuree, formatPrix } from "@/lib/format";

// Résultat d'une lecture, rattaché à sa demande (prestation, coiffeur, essai) :
// tant que la clé ne correspond pas à la demande en cours, on affiche le
// chargement.
type Resultat = { cle: string } & ({ erreur: true } | { erreur: false; creneaux: Creneau[] });

// Écran 2 : créneaux libres par jour, filtre coiffeur (« Peu importe » par
// défaut, BNF-9). Le catalogue arrive avec la page statique ; seuls les
// créneaux sont lus au chargement, sans connexion (BF-C1).
export function EcranCreneaux({ catalogue }: { catalogue: Catalogue }) {
  const prestationId = useSearchParams().get("prestation") ?? "";
  const prestation = catalogue.prestations.find((p) => p.id === prestationId);
  const [coiffeurId, setCoiffeurId] = useState("");
  const [essai, setEssai] = useState(0);
  const [resultat, setResultat] = useState<Resultat | null>(null);
  const idFiltre = useId();
  const cle = `${prestationId}|${coiffeurId}|${essai}`;

  useEffect(() => {
    if (!prestation) return;
    const abandon = new AbortController();
    const { du, au } = periode(new Date(), catalogue.fuseau);

    lireCreneaux(
      { prestationId: prestation.id, du, au, coiffeurId: coiffeurId || undefined },
      abandon.signal,
    ).then(
      (creneaux) => setResultat({ cle, erreur: false, creneaux }),
      () => {
        if (!abandon.signal.aborted) setResultat({ cle, erreur: true });
      },
    );

    return () => abandon.abort();
  }, [cle, prestation, coiffeurId, catalogue.fuseau]);

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
          jours={grouperParJour(resultat.creneaux, catalogue.fuseau)}
          prestationId={prestation.id}
          coiffeurId={coiffeurId || undefined}
        />
      )}
    </div>
  );
}

function Creneaux(props: Parameters<typeof ListeCreneaux>[0]) {
  if (props.jours.length === 0) {
    return (
      <p role="status" className="text-base text-texte">
        Aucun créneau libre sur les {JOURS_AFFICHES} prochains jours
        {props.coiffeurId ? " avec ce coiffeur. Essayez « Peu importe »." : "."}
      </p>
    );
  }
  return <ListeCreneaux {...props} />;
}
