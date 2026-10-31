"use client";

import { useEffect, useState } from "react";
import {
  CompteConnecte,
  FormulaireConnexion,
  useCompte,
} from "@/components/connexion/connexion-code";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { LienRetour } from "@/components/ui/lien-retour";
import { Carte } from "@/components/ui/carte";
import { lienSecondaire } from "@/components/ui/styles";
import { lienTelephone } from "@/lib/accueil";
import { formatDuree, formatPrix } from "@/lib/format";
import {
  annuler,
  libelleStatut,
  lireMesReservations,
  messageDelaiPasse,
  separer,
  type MaReservation,
  type ResultatAnnulation,
} from "@/lib/mes-reservations";
import { jourEtHeure } from "@/lib/reservation";
import { createClient } from "@/lib/supabase/client";

// « Mes réservations » (BF-C6) : à venir et historique, annulation des
// réservations à venir avec confirmation. Connexion par code e-mail sur le
// même écran si besoin.
// delaiAnnulation : délai minimum d'annulation du salon, en minutes (issue 118).
// telephone : numéro du salon, proposé quand le délai est passé (issue 129).
export function EcranMesReservations({
  salonId,
  fuseau,
  delaiAnnulation = 0,
  telephone = null,
}: {
  salonId: string;
  fuseau: string;
  delaiAnnulation?: number;
  telephone?: string | null;
}) {
  const [supabase] = useState(createClient);
  const compte = useCompte(supabase);

  return (
    <div className="flex flex-col gap-6">
      <LienRetour href="/" vers="à l'accueil" libelle="Accueil" />

      <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">Mes réservations</h1>

      {compte === undefined ? (
        <p className="text-base text-texte-secondaire">Vérification de la connexion…</p>
      ) : compte ? (
        <>
          <CompteConnecte supabase={supabase} compte={compte} />
          {/* key : relit tout au changement de compte. */}
          <Reservations
            key={compte}
            supabase={supabase}
            salonId={salonId}
            fuseau={fuseau}
            delaiAnnulation={delaiAnnulation}
            telephone={telephone}
          />
        </>
      ) : (
        <FormulaireConnexion
          supabase={supabase}
          demanderNom={false}
          introduction="Connectez-vous avec l'e-mail utilisé pour réserver : vous recevrez un code à 6 chiffres. Pas de mot de passe."
        />
      )}
    </div>
  );
}

type Client = ReturnType<typeof createClient>;

function Reservations({
  supabase,
  salonId,
  fuseau,
  delaiAnnulation,
  telephone,
}: {
  supabase: Client;
  salonId: string;
  fuseau: string;
  delaiAnnulation: number;
  telephone: string | null;
}) {
  // undefined : en cours de lecture ; null : erreur.
  const [reservations, setReservations] = useState<MaReservation[] | null | undefined>(undefined);
  const [maintenant, setMaintenant] = useState(() => new Date());
  const [annulee, setAnnulee] = useState<string | null>(null);

  async function relire() {
    const lues = await lireMesReservations(supabase, salonId);
    setMaintenant(new Date());
    setReservations(lues);
  }

  useEffect(() => {
    let actif = true;
    lireMesReservations(supabase, salonId).then((lues) => {
      if (!actif) return;
      setMaintenant(new Date());
      setReservations(lues);
    });
    return () => {
      actif = false;
    };
  }, [supabase, salonId]);

  if (reservations === undefined) {
    return <p className="text-base text-texte-secondaire">Chargement des réservations…</p>;
  }
  if (reservations === null) {
    return (
      <div role="alert" className="flex flex-col items-start gap-3">
        <p className="text-base text-erreur">Impossible de lire vos réservations.</p>
        <Bouton variante="secondaire" onClick={relire}>
          Réessayer
        </Bouton>
      </div>
    );
  }

  const { aVenir, historique } = separer(reservations, maintenant);

  return (
    <>
      {annulee && (
        <p role="status" className="text-base font-semibold text-accent">
          {annulee}
        </p>
      )}

      <section aria-labelledby="titre-a-venir" className="flex flex-col gap-4">
        <h2 id="titre-a-venir" className="font-titre text-xl font-medium text-texte">
          À venir
        </h2>
        {aVenir.length === 0 ? (
          <div className="flex flex-col items-start gap-4">
            <p className="text-base text-texte-secondaire">Aucune réservation à venir.</p>
            <BoutonLien href="/reserver">Réserver</BoutonLien>
          </div>
        ) : (
          <ul className="flex flex-col gap-4">
            {aVenir.map((r) => (
              <li key={r.id}>
                <CarteReservation
                  reservation={r}
                  fuseau={fuseau}
                  maintenant={maintenant}
                  delaiAnnulation={delaiAnnulation}
                  telephone={telephone}
                  supabase={supabase}
                  onAnnulee={(message) => {
                    setAnnulee(message);
                    relire();
                  }}
                />
              </li>
            ))}
          </ul>
        )}
      </section>

      {historique.length > 0 && (
        <section aria-labelledby="titre-historique" className="flex flex-col gap-4">
          <h2 id="titre-historique" className="font-titre text-xl font-medium text-texte">
            Passées et annulées
          </h2>
          <ul className="flex flex-col gap-4">
            {historique.map((r) => (
              <li key={r.id}>
                <CarteReservation reservation={r} fuseau={fuseau} maintenant={maintenant} />
              </li>
            ))}
          </ul>
        </section>
      )}
    </>
  );
}

// Détail d'une réservation ; « Annuler » si elle est annulable, avec une
// confirmation sur la carte même.
function CarteReservation({
  reservation,
  fuseau,
  maintenant,
  delaiAnnulation = 0,
  telephone = null,
  supabase,
  onAnnulee,
}: {
  reservation: MaReservation;
  fuseau: string;
  maintenant: Date;
  delaiAnnulation?: number;
  telephone?: string | null;
  supabase?: Client;
  onAnnulee?: (message: string) => void;
}) {
  const [confirmation, setConfirmation] = useState(false);
  const [enCours, setEnCours] = useState(false);
  const [echec, setEchec] = useState<Exclude<ResultatAnnulation, "annulee"> | null>(null);

  const { jour, heure } = jourEtHeure(reservation.debut, fuseau);
  const lignes: [string, string][] = [
    ["Coiffeur", reservation.coiffeur],
    ["Date", jour],
    ["Heure", heure],
    ["Durée", formatDuree(reservation.dureeMinutes)],
    ["Prix", formatPrix(reservation.prix)],
    ["Statut", libelleStatut(reservation.statut, reservation.debut, maintenant)],
  ];

  async function confirmerAnnulation() {
    if (!supabase) return;
    setEnCours(true);
    const resultat = await annuler(supabase, reservation.id);
    setEnCours(false);
    if (resultat === "annulee") {
      onAnnulee?.(`Réservation du ${jour.toLowerCase()} à ${heure} annulée.`);
      return;
    }
    setEchec(resultat);
  }

  return (
    <Carte className="flex flex-col gap-4">
      <h3 className="text-lg font-semibold text-texte">{reservation.prestation}</h3>
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2">
        {lignes.map(([terme, valeur]) => (
          <div key={terme} className="contents">
            <dt className="text-base text-texte-secondaire">{terme}</dt>
            <dd className="text-base font-semibold text-texte tabular-nums">
              {terme === "Statut" ? (
                // Statut en pastille (#55) : `accent` si confirmée, gris sinon.
                <span
                  className={`inline-block rounded-pastille border px-3 ${
                    valeur === "Confirmée" ? "border-accent text-accent" : "border-bordure text-texte-secondaire"
                  }`}
                >
                  {valeur}
                </span>
              ) : (
                valeur
              )}
            </dd>
          </div>
        ))}
      </dl>

      {/* Délai d'annulation passé (issue 118) : le message remplace « Annuler ». */}
      {messageDelaiPasse(reservation, maintenant, delaiAnnulation) && (
        <div className="flex flex-col items-start gap-1">
          <p className="text-base text-texte-secondaire">
            {messageDelaiPasse(reservation, maintenant, delaiAnnulation)}
          </p>
          {telephone && (
            <a
              href={lienTelephone(telephone)}
              aria-label={`Appeler le salon au ${telephone}`}
              className={lienSecondaire}
            >
              Appeler le salon
            </a>
          )}
        </div>
      )}

      {reservation.annulable && supabase && (
        <div className="flex flex-col items-start gap-3">
          {echec && (
            <p role="alert" className="text-base text-erreur">
              {echec === "impossible"
                ? "Cette réservation ne peut plus être annulée."
                : echec === "deconnecte"
                  ? "Votre connexion a expiré. Changez de compte pour recevoir un nouveau code."
                  : "L'annulation n'a pas pu être enregistrée. Réessayez."}
            </p>
          )}
          {confirmation ? (
            <div
              role="group"
              aria-label="Confirmer l'annulation"
              className="flex flex-col items-start gap-3"
            >
              <p className="text-base text-texte">
                Annuler cette réservation ? Le créneau sera proposé à d&apos;autres clients.
              </p>
              <div className="flex flex-wrap gap-3">
                <Bouton
                  onClick={confirmerAnnulation}
                  chargement={enCours}
                  libelleChargement="Annulation…"
                >
                  Oui, annuler
                </Bouton>
                <Bouton variante="secondaire" onClick={() => setConfirmation(false)}>
                  Non, garder
                </Bouton>
              </div>
            </div>
          ) : (
            <Bouton variante="secondaire" onClick={() => setConfirmation(true)}>
              Annuler la réservation
            </Bouton>
          )}
        </div>
      )}
    </Carte>
  );
}
