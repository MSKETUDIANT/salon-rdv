import { useId, type InputHTMLAttributes } from "react";
import { focus } from "@/components/ui/styles";

// Champ de saisie : libellé toujours visible au-dessus ; placeholder en
// `texte-secondaire` (c'est du texte : 4,5:1) ; en erreur, bordure de 2 px et
// message en `erreur`, message relié au champ pour les lecteurs d'écran.
type Props = Omit<InputHTMLAttributes<HTMLInputElement>, "id"> & {
  libelle: string;
  erreur?: string;
};

export function Champ({ libelle, erreur, className, ...props }: Props) {
  const id = useId();
  const idErreur = `${id}-erreur`;

  return (
    <div className="flex flex-col gap-2">
      <label htmlFor={id} className="text-base font-semibold text-texte">
        {libelle}
      </label>
      <input
        {...props}
        id={id}
        aria-invalid={erreur ? true : undefined}
        aria-describedby={erreur ? idErreur : undefined}
        className={`h-12 rounded-base bg-surface px-4 text-base text-texte placeholder:text-texte-secondaire ${focus} ${
          erreur ? "border-2 border-erreur" : "border border-bordure"
        } ${className ?? ""}`}
      />
      {erreur && (
        <p id={idErreur} className="text-base text-erreur">
          {erreur}
        </p>
      )}
    </div>
  );
}
