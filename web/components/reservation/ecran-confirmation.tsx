"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import {
  CompteConnecte,
  FormulaireConnexion,
  useCompte,
  type EtapeConnexion,
} from "@/components/connexion/connexion-code";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { Carte } from "@/components/ui/carte";
import { focus } from "@/components/ui/styles";
import type { Catalogue } from "@/lib/catalogue";
import { formatDuree, formatPrix } from "@/lib/format";
import {
  jourEtHeure,
  lienCreneaux,
  lireDemande,
  reserver,
  type Demande,
  type ResultatReservation,
} from "@/lib/reservation";
import { createClient } from "@/lib/supabase/client";

// Écran 3 : récapitulatif, connexion par code à 6 chiffres reçu par e-mail
// sans quitter l'écran (BF-C4), puis confirmation (BF-C5). « Confirmer »
// n'est jamais désactivé : au clic, ce qui manque est indiqué.
export function EcranConfirmation({ catalogue }: { catalogue: Catalogue }) {
  const demande = lireDemande(useSearchParams(), catalogue);

  if (!demande) {
    return (
      <div className="flex flex-col items-start gap-6">
        <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
          Créneau introuvable
        </h1>
        <BoutonLien href="/reserver">Voir les prestations</BoutonLien>
      </div>
    );
  }
  return <Confirmation demande={demande} catalogue={catalogue} />;
}

function Confirmation({ demande, catalogue }: { demande: Demande; catalogue: Catalogue }) {
  const [supabase] = useState(createClient);
  const compte = useCompte(supabase);
  const [etape, setEtape] = useState<EtapeConnexion>("email");
  const [enCours, setEnCours] = useState(false);
  const [manque, setManque] = useState<string | null>(null);
  const [resultat, setResultat] = useState<ResultatReservation | null>(null);

  async function confirmer() {
    if (!compte) {
      setManque(
        etape === "email"
          ? "Pour confirmer, indiquez votre nom et votre e-mail, puis saisissez le code reçu."
          : "Pour confirmer, saisissez le code à 6 chiffres reçu par e-mail.",
      );
      return;
    }
    setManque(null);
    setEnCours(true);
    const reponse = await reserver(supabase, demande);
    setEnCours(false);
    setResultat(reponse);
  }

  if (resultat?.statut === "confirmee") {
    const coiffeur = catalogue.coiffeurs.find((c) => c.id === resultat.coiffeurId);
    return (
      <div className="flex flex-col items-start gap-6">
        <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
          Réservation confirmée
        </h1>
        <Recapitulatif demande={demande} fuseau={catalogue.fuseau} coiffeur={coiffeur?.nom} />
        <p className="text-base text-texte">À bientôt au salon.</p>
        <BoutonLien href="/mes-reservations">Voir mes réservations</BoutonLien>
        <Link
          href="/"
          className={`inline-flex min-h-11 items-center rounded-base text-base font-semibold text-accent underline ${focus}`}
        >
          Retour à l&apos;accueil
        </Link>
      </div>
    );
  }

  const retour = lienCreneaux(demande.prestation.id, demande.coiffeur?.id);

  return (
    <div className="flex flex-col gap-6">
      <Link
        href={retour}
        className={`inline-flex min-h-11 items-center self-start rounded-base text-base font-semibold text-accent underline ${focus}`}
      >
        ← Changer de créneau
      </Link>

      <h1 className="font-titre text-2xl font-medium text-texte sm:text-3xl">
        Confirmer la réservation
      </h1>

      <Recapitulatif
        demande={demande}
        fuseau={catalogue.fuseau}
        coiffeur={demande.coiffeur?.nom ?? "Peu importe (attribué à la confirmation)"}
      />

      <section aria-labelledby="titre-coordonnees" className="flex flex-col gap-4">
        <h2 id="titre-coordonnees" className="font-titre text-xl font-medium text-texte">
          Vos coordonnées
        </h2>

        {compte === undefined ? (
          <p className="text-base text-texte-secondaire">Vérification de la connexion…</p>
        ) : compte ? (
          <CompteConnecte supabase={supabase} compte={compte} />
        ) : (
          <FormulaireConnexion
            supabase={supabase}
            demanderNom
            introduction="Recevez un code à 6 chiffres par e-mail pour confirmer. Pas de mot de passe."
            onEtape={(nouvelle) => {
              setEtape(nouvelle);
              if (nouvelle === "code") setManque(null);
            }}
          />
        )}
      </section>

      <div className="flex flex-col items-start gap-3">
        {/* Une fois connecté, ce qui manquait ne manque plus. */}
        {manque && !compte && (
          <p role="alert" className="text-base text-erreur">
            {manque}
          </p>
        )}
        {resultat?.statut === "pris" && (
          <div role="alert" className="flex flex-col items-start gap-3">
            <p className="text-base text-erreur">
              Ce créneau vient d&apos;être pris. Choisissez-en un autre.
            </p>
            <BoutonLien href={retour}>Choisir un autre créneau</BoutonLien>
          </div>
        )}
        {resultat?.statut === "deconnecte" && (
          <p role="alert" className="text-base text-erreur">
            Votre connexion a expiré. Changez de compte pour recevoir un nouveau code.
          </p>
        )}
        {resultat?.statut === "erreur" && (
          <p role="alert" className="text-base text-erreur">
            La réservation n&apos;a pas pu être enregistrée. Réessayez.
          </p>
        )}
        {resultat?.statut !== "pris" && (
          <Bouton
            onClick={confirmer}
            chargement={enCours}
            libelleChargement="Réservation…"
          >
            Confirmer la réservation
          </Bouton>
        )}
      </div>
    </div>
  );
}

function Recapitulatif({
  demande,
  fuseau,
  coiffeur,
}: {
  demande: Demande;
  fuseau: string;
  coiffeur?: string;
}) {
  const { jour, heure } = jourEtHeure(demande.debut, fuseau);
  const lignes: [string, string][] = [
    ["Prestation", demande.prestation.nom],
    ["Coiffeur", coiffeur ?? ""],
    ["Date", jour],
    ["Heure", heure],
    ["Durée", formatDuree(demande.prestation.dureeMinutes)],
    ["Prix", formatPrix(demande.prestation.prix)],
  ];

  return (
    <Carte className="w-full">
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2">
        {lignes.map(([terme, valeur]) => (
          <div key={terme} className="contents">
            <dt className="text-base text-texte-secondaire">{terme}</dt>
            <dd className="text-base font-semibold text-texte tabular-nums">{valeur}</dd>
          </div>
        ))}
      </dl>
    </Carte>
  );
}
