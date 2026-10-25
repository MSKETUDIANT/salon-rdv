"use client";

import { useEffect, useState, type FormEvent } from "react";
import { Bouton } from "@/components/ui/bouton";
import { Champ } from "@/components/ui/champ";
import { focus } from "@/components/ui/styles";
import { codeValide, emailValide, envoyerCode, validerCode } from "@/lib/reservation";
import type { createClient } from "@/lib/supabase/client";

// Connexion par code à 6 chiffres reçu par e-mail (charte §5), sans quitter
// l'écran : écran de confirmation (#6) et « Mes réservations » (#7).

type Client = ReturnType<typeof createClient>;
export type EtapeConnexion = "email" | "code";

// E-mail du compte connecté ; undefined : session pas encore lue ; null : pas
// connecté.
export function useCompte(supabase: Client): string | null | undefined {
  const [compte, setCompte] = useState<string | null | undefined>(undefined);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setCompte(data.session?.user.email ?? null));
    const { data } = supabase.auth.onAuthStateChange((_evenement, session) =>
      setCompte(session?.user.email ?? null),
    );
    return () => data.subscription.unsubscribe();
  }, [supabase]);

  return compte;
}

// demanderNom : le nom n'est utile qu'à la création du compte (écran de
// confirmation). Sans nom, connexion à un compte existant seulement.
export function FormulaireConnexion({
  supabase,
  demanderNom,
  introduction,
  onEtape,
}: {
  supabase: Client;
  demanderNom: boolean;
  introduction: string;
  onEtape?: (etape: EtapeConnexion) => void;
}) {
  const [etape, setEtape] = useState<EtapeConnexion>("email");
  const [nom, setNom] = useState("");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [erreurs, setErreurs] = useState<{ nom?: string; email?: string; code?: string }>({});
  const [enCours, setEnCours] = useState<"code" | "validation" | null>(null);

  function changerEtape(nouvelle: EtapeConnexion) {
    setEtape(nouvelle);
    onEtape?.(nouvelle);
  }

  async function demanderCode(evenement: FormEvent) {
    evenement.preventDefault();
    const nouvelles = {
      nom: !demanderNom || nom.trim() ? undefined : "Indiquez votre nom.",
      email: emailValide(email.trim()) ? undefined : "Indiquez une adresse e-mail valide.",
    };
    setErreurs(nouvelles);
    if (nouvelles.nom || nouvelles.email) return;

    setEnCours("code");
    const erreur = await envoyerCode(supabase, email.trim(), demanderNom ? nom.trim() : null);
    setEnCours(null);
    if (erreur) {
      setErreurs({ email: erreur });
      return;
    }
    setCode("");
    changerEtape("code");
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
  }

  if (etape === "email") {
    return (
      <form onSubmit={demanderCode} noValidate className="flex flex-col gap-4">
        <p className="text-base text-texte">{introduction}</p>
        {demanderNom && (
          <Champ
            libelle="Nom"
            autoComplete="name"
            value={nom}
            onChange={(e) => setNom(e.target.value)}
            erreur={erreurs.nom}
          />
        )}
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
    );
  }

  return (
    <form onSubmit={verifierCode} noValidate className="flex flex-col gap-4">
      <p className="text-base text-texte">
        Code envoyé à <span className="font-semibold break-all">{email.trim()}</span>. Il expire
        dans une heure.
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
          changerEtape("email");
          setErreurs({});
        }}
        className={`inline-flex min-h-11 items-center self-start rounded-base text-base font-semibold text-accent underline ${focus}`}
      >
        Changer d&apos;e-mail ou renvoyer le code
      </button>
    </form>
  );
}

// « Connecté avec … » et changement de compte.
export function CompteConnecte({ supabase, compte }: { supabase: Client; compte: string }) {
  return (
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
  );
}
