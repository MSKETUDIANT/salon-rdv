import { describe, expect, it } from "vitest";
import { exiger } from "@/lib/env";

describe("exiger", () => {
  it("renvoie la valeur présente", () => {
    expect(exiger("NEXT_PUBLIC_SALON_ID", "abc")).toBe("abc");
  });

  it("refuse une variable absente ou vide, en la nommant", () => {
    expect(() => exiger("NEXT_PUBLIC_SALON_ID", undefined)).toThrow("NEXT_PUBLIC_SALON_ID");
    expect(() => exiger("NEXT_PUBLIC_SALON_ID", "")).toThrow("NEXT_PUBLIC_SALON_ID");
  });
});
