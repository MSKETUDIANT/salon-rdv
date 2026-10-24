"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useEffect, useState, type FormEvent } from "react";
import { Bouton } from "@/components/ui/bouton";
import { BoutonLien } from "@/components/ui/bouton-lien";
import { Carte } from "@/components/ui/carte";
import { Champ } from "@/components/ui/champ";
import { focus } from "@/components/ui/styles";
import type { Catalogue } from "@/lib/catalogue";
import { formatDuree, formatPrix } from "@/lib/format";
import {
  codeValide,
  emailValide,
  envoyerCode,
  jourEtHeure,
  lienCreneaux,
  lireDemande,
  reserver,
  validerCode,
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
  // undefined : session pas encore lue ; null : pas connecté.
  const [compte, setCompte] = useState<string | null | undefined>(undefined);
  const [etape, setEtape] = useState<"email" | "code">("email");
  const [nom, setNom] = useState("");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [erreurs, setErreurs] = useState<{ nom?: string; email?: string; code?: string }>({});
  const [enCours, setEnCours] = useState<"code" | "validation" | "reservation" | null>(null);
  const [manque, setManque] = useState<string | null>(null);
  const [resultat, setResultat] = useState<ResultatReservation | null>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setCompte(data.session?.user.email ?? null));
    const { data } = supabase.auth.onAuthStateChange((_evenement, session) =>
      setCompte(session?.user.email ?? null),
    );
    return () => data.subscription.unsubscribe();
  }, [supabase]);

  async function demanderCode(evenement: FormEvent) {
    evenement.preventDefault();
    const nouvelles = {
      nom: nom.trim() ? undefined : "Indiquez votre nom.",
      email: emailValide(email.trim()) ? undefined : "Indiquez une adresse e-mail valide.",
    };
    setErreurs(nouvelles);
    if (nouvelles.nom || nouvelles.email) return;

    setEnCours("code");
    const erreur = await envoyerCode(supabase, email.trim(), nom.trim());
    setEnCours(null);
    if (erreur) {
      setErreurs({ email: erreur });
      return;
    }
    setManque(null);
    setCode("");
    setEtape("code");
  }

  async function verifierCode(evenement: FormEvent) {
    evenement.preventDefault();
    if (!codeValide(code)) {
      setErreurs({ code: "Le code compte 6 chiffres." });
      return;
    }
    setEnCours("validation");
    const erreur = await validerCode(supabase, email.trim(), code);
    setEnCours(null);
    setErreurs(erreur ? { code: erreur } : {});
    if (!erreur) setManque(null);
  }

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
    setEnCours("reservation");
    const reponse = await reserver(supabase, demande);
    setEnCours(null);
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
        <BoutonLien href="/">Retour à l&apos;accueil</BoutonLien>
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
          <div className="flex flex-col items-start gap-2">
            <p className="text-base text-texte">
              Connecté avec <span className="font-semibold break-all">{compte}</span>
            </p>
            <button
              type="button"
              onClick={() => supabase.auth.signOut()}
              className={`inline-flex min-h-11 items-center rounded-base text-base font-semibold text-accent underline ${focus}`}
            >
              Changer de compte
            </button>
          </div>
        ) : etape === "email" ? (
          <form onSubmit={demanderCode} noValidate className="flex flex-col gap-4">
            <p className="text-base text-texte">
              Recevez un code à 6 chiffres par e-mail pour confirmer. Pas de mot de passe.
            </p>
            <Champ
              libelle="Nom"
              autoComplete="name"
              value={nom}
              onChange={(e) => setNom(e.target.value)}
              erreur={erreurs.nom}
            />
            <Champ
              libelle="E-mail"
              type="email"
              inputMode="email"
              autoComplete="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              erreur={erreurs.email}
            />
            <Bouton
              type="submit"
              variante="secondaire"
              chargement={enCours === "code"}
              libelleChargement="Envoi du code…"
              className="self-start"
            >
              Recevoir le code
            </Bouton>
          </form>
        ) : (
          <form onSubmit={verifierCode} noValidate className="flex flex-col gap-4">
            <p className="text-base text-texte">
              Code envoyé à <span className="font-semibold break-all">{email.trim()}</span>. Il
              expire dans une heure.
            </p>
            <Champ
              libelle="Code à 6 chiffres"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              autoFocus
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
              erreur={erreurs.code}
            />
            <Bouton
              type="submit"
              variante="secondaire"
              chargement={enCours === "validation"}
              libelleChargement="Vérification…"
              className="self-start"
            >
              Valider le code
            </Bouton>
            <button
              type="button"
              onClick={() => {
                setEtape("email");
                setErreurs({});
              }}
              className={`inline-flex min-h-11 items-center self-start rounded-base text-base font-semibold text-accent underline ${focus}`}
            >
              Changer d&apos;e-mail ou renvoyer le code
            </button>
          </form>
        )}
      </section>

      <div className="flex flex-col items-start gap-3">
        {manque && (
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
            chargement={enCours === "reservation"}
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
