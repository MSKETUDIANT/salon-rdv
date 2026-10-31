"use client";

import { useSearchParams } from "next/navigation";
import { useEffect, useId, useMemo, useState } from "react";
import { BandeJours } from "@/components/reservation/bande-jours";
import { ListeCreneaux } from "@/components/reservation/liste-creneaux";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { LienRetour } from "@/components/ui/lien-retour";
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

// Résultat d'une lecture, rattaché à sa demande (prestation, coiffeur, essai) :
// tant que la clé ne correspond pas à la demande en cours, on affiche le
// chargement.
type Resultat = { cle: string } & (
  | { erreur: true }
  | { erreur: false; du: string; creneaux: Creneau[] }
);

// Créneaux lus par le serveur pour la prestation et le coiffeur de l'URL
// (#46) : affichés dès le HTML, sans nouvelle lecture.
export type CreneauxInitiaux = {
  prestationId: string;
  coiffeurId: string;
  du: string;
  creneaux: Creneau[];
};

// Écran 2 : bande des jours, créneaux du jour choisi (par défaut, le premier
// jour disponible), filtre coiffeur (« Peu importe » par défaut, BNF-9). La
// première liste vient du serveur (initiaux, #46) ; un autre coiffeur ou
// « Réessayer » relit les créneaux depuis le navigateur, sans connexion
// (BF-C1).
export function EcranCreneaux({
  catalogue,
  initiaux,
}: {
  catalogue: Catalogue;
  initiaux?: CreneauxInitiaux;
}) {
  const params = useSearchParams();
  const prestationId = params.get("prestation") ?? "";
  const prestation = catalogue.prestations.find((p) => p.id === prestationId);
  // Filtre repris de l'URL (retour depuis l'écran 3), s'il est valable.
  const [coiffeurId, setCoiffeurId] = useState(() => {
    const demande = params.get("coiffeur") ?? "";
    return coiffeursCompetents(catalogue, prestationId).some((c) => c.id === demande) ? demande : "";
  });
  const [essai, setEssai] = useState(0);
  const idFiltre = useId();
  // Retour de l'écran 3 après un refus (#51) : liste relue (par le serveur),
  // message en tête.
  const pris = params.get("pris") === "1";
  // Prestation choisie sur l'accueil (issue 129) : « Retour » ramène à sa
  // liste, sinon à l'écran 1, comme le retour de Planity ou Doctolib.
  const depuisAccueil = params.get("depuis") === "accueil";
  const cle = `${prestationId}|${coiffeurId}|${essai}|${pris}`;
  const [resultat, setResultat] = useState<Resultat | null>(() =>
    initiaux &&
    initiaux.prestationId === prestationId &&
    initiaux.coiffeurId === coiffeurId
      ? { cle, erreur: false, du: initiaux.du, creneaux: initiaux.creneaux }
      : null,
  );
  // Recalculés seulement à chaque nouvelle lecture : le jour choisi tient tant
  // que la lecture ne change pas.
  const jours = useMemo(
    () =>
      resultat && !resultat.erreur
        ? grouperParJour(resultat.creneaux, catalogue.fuseau, resultat.du)
        : [],
    [resultat, catalogue.fuseau],
  );

  // Lecture depuis le navigateur seulement si la liste affichée ne correspond
  // pas à la demande (autre coiffeur, « Réessayer », pas de liste du serveur).
  const aJour = resultat?.cle === cle && !resultat.erreur;
  useEffect(() => {
    if (!prestation || aJour) return;
    const abandon = new AbortController();
    const { du, au } = periode(new Date(), catalogue.fuseau);

    const demande = { prestationId: prestation.id, du, au, coiffeurId: coiffeurId || undefined };
    lireCreneaux(demande, abandon.signal).then(
      (creneaux) => setResultat({ cle, erreur: false, du, creneaux }),
      () => {
        if (!abandon.signal.aborted) setResultat({ cle, erreur: true });
      },
    );

    return () => abandon.abort();
  }, [cle, aJour, prestation, coiffeurId, catalogue.fuseau]);

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
      {depuisAccueil ? (
        <LienRetour href="/#prestations" vers="aux prestations de l'accueil" />
      ) : (
        <LienRetour href="/reserver" vers="aux prestations" />
      )}

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
          depuisAccueil={depuisAccueil}
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
  depuisAccueil,
}: {
  jours: Jour[];
  prestationId: string;
  coiffeurId?: string;
  depuisAccueil: boolean;
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
      <ListeCreneaux
        jour={jour}
        prestationId={prestationId}
        coiffeurId={coiffeurId}
        depuisAccueil={depuisAccueil}
      />
    </div>
  );
}
