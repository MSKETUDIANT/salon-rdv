// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { PhotoAccueil } from "@/components/photo-accueil";

// next/image remplacé par une simple image : on vérifie la source et le texte
// alternatif choisis, pas l'optimisation (vérifiée sur un build).
vi.mock("next/image", () => ({
  default: ({
    src,
    alt,
    fill,
    onError,
  }: {
    src: string | { src: string };
    alt: string;
    fill?: boolean;
    onError?: () => void;
  }) => (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={typeof src === "string" ? src : src.src}
      alt={alt}
      data-fill={fill ? "oui" : "non"}
      onError={onError}
    />
  ),
}));

afterEach(cleanup);

describe("PhotoAccueil", () => {
  it("photo envoyée par le gérant : son adresse, texte alternatif avec le nom du salon", () => {
    const adresse = "https://exemple.supabase.co/storage/v1/object/public/salons/s/1.jpg";
    render(<PhotoAccueil photo={adresse} nom="Salon de démo" />);
    const image = screen.getByRole("img");
    expect(image.getAttribute("src")).toBe(adresse);
    expect(image.getAttribute("alt")).toBe("Photo du salon Salon de démo");
    // Recadrée en 4:3 par son cadre.
    expect(image.dataset.fill).toBe("oui");
    expect(image.parentElement?.className).toContain("aspect-4/3");
  });

  it("photo qui ne se charge pas (ancien fichier supprimé) : la photo de démonstration", () => {
    render(<PhotoAccueil photo="https://exemple.supabase.co/x.jpg" nom="Salon de démo" />);
    fireEvent.error(screen.getByRole("img"));
    expect(screen.getByRole("img").getAttribute("alt")).toBe(
      "Fauteuil de coiffure devant un meuble en bois et un miroir rond",
    );
  });

  it("sans photo : la photo de démonstration", () => {
    render(<PhotoAccueil photo={null} nom="Salon de démo" />);
    const image = screen.getByRole("img");
    expect(image.getAttribute("alt")).toBe(
      "Fauteuil de coiffure devant un meuble en bois et un miroir rond",
    );
    expect(image.getAttribute("src")).toContain("accueil-salon");
  });
});
