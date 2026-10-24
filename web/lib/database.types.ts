export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      absences: {
        Row: {
          coiffeur_id: string
          debut: string
          fin: string
          id: string
          motif: string | null
          salon_id: string
        }
        Insert: {
          coiffeur_id: string
          debut: string
          fin: string
          id?: string
          motif?: string | null
          salon_id: string
        }
        Update: {
          coiffeur_id?: string
          debut?: string
          fin?: string
          id?: string
          motif?: string | null
          salon_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "absences_coiffeur_id_fkey"
            columns: ["coiffeur_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "absences_salon_id_fkey"
            columns: ["salon_id"]
            isOneToOne: false
            referencedRelation: "salons"
            referencedColumns: ["id"]
          },
        ]
      }
      competences: {
        Row: {
          coiffeur_id: string
          prestation_id: string
        }
        Insert: {
          coiffeur_id: string
          prestation_id: string
        }
        Update: {
          coiffeur_id?: string
          prestation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "competences_coiffeur_id_fkey"
            columns: ["coiffeur_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competences_prestation_id_fkey"
            columns: ["prestation_id"]
            isOneToOne: false
            referencedRelation: "prestations"
            referencedColumns: ["id"]
          },
        ]
      }
      encaissements: {
        Row: {
          created_at: string
          encaisse_par: string | null
          id: string
          montant: number
          reservation_id: string
        }
        Insert: {
          created_at?: string
          encaisse_par?: string | null
          id?: string
          montant: number
          reservation_id: string
        }
        Update: {
          created_at?: string
          encaisse_par?: string | null
          id?: string
          montant?: number
          reservation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "encaissements_encaisse_par_fkey"
            columns: ["encaisse_par"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "encaissements_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: true
            referencedRelation: "reservations"
            referencedColumns: ["id"]
          },
        ]
      }
      horaires: {
        Row: {
          coiffeur_id: string
          heure_debut: string
          heure_fin: string
          id: string
          jour_semaine: number
          salon_id: string
        }
        Insert: {
          coiffeur_id: string
          heure_debut: string
          heure_fin: string
          id?: string
          jour_semaine: number
          salon_id: string
        }
        Update: {
          coiffeur_id?: string
          heure_debut?: string
          heure_fin?: string
          id?: string
          jour_semaine?: number
          salon_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "horaires_coiffeur_id_fkey"
            columns: ["coiffeur_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "horaires_salon_id_fkey"
            columns: ["salon_id"]
            isOneToOne: false
            referencedRelation: "salons"
            referencedColumns: ["id"]
          },
        ]
      }
      prestations: {
        Row: {
          active: boolean
          duree_minutes: number
          id: string
          nom: string
          prix: number
          salon_id: string
        }
        Insert: {
          active?: boolean
          duree_minutes: number
          id?: string
          nom: string
          prix: number
          salon_id: string
        }
        Update: {
          active?: boolean
          duree_minutes?: number
          id?: string
          nom?: string
          prix?: number
          salon_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "prestations_salon_id_fkey"
            columns: ["salon_id"]
            isOneToOne: false
            referencedRelation: "salons"
            referencedColumns: ["id"]
          },
        ]
      }
      reservations: {
        Row: {
          client_id: string
          coiffeur_id: string
          created_at: string
          debut: string
          fin: string
          id: string
          prestation_id: string
          salon_id: string
          statut: Database["public"]["Enums"]["statut_reservation"]
        }
        Insert: {
          client_id: string
          coiffeur_id: string
          created_at?: string
          debut: string
          fin: string
          id?: string
          prestation_id: string
          salon_id: string
          statut?: Database["public"]["Enums"]["statut_reservation"]
        }
        Update: {
          client_id?: string
          coiffeur_id?: string
          created_at?: string
          debut?: string
          fin?: string
          id?: string
          prestation_id?: string
          salon_id?: string
          statut?: Database["public"]["Enums"]["statut_reservation"]
        }
        Relationships: [
          {
            foreignKeyName: "reservations_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_coiffeur_id_fkey"
            columns: ["coiffeur_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_prestation_id_fkey"
            columns: ["prestation_id"]
            isOneToOne: false
            referencedRelation: "prestations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reservations_salon_id_fkey"
            columns: ["salon_id"]
            isOneToOne: false
            referencedRelation: "salons"
            referencedColumns: ["id"]
          },
        ]
      }
      roles_utilisateur: {
        Row: {
          role: Database["public"]["Enums"]["role"]
          salon_id: string
          utilisateur_id: string
        }
        Insert: {
          role: Database["public"]["Enums"]["role"]
          salon_id: string
          utilisateur_id: string
        }
        Update: {
          role?: Database["public"]["Enums"]["role"]
          salon_id?: string
          utilisateur_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_utilisateur_salon_id_fkey"
            columns: ["salon_id"]
            isOneToOne: false
            referencedRelation: "salons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "roles_utilisateur_utilisateur_id_fkey"
            columns: ["utilisateur_id"]
            isOneToOne: false
            referencedRelation: "utilisateurs"
            referencedColumns: ["id"]
          },
        ]
      }
      salons: {
        Row: {
          adresse: string | null
          created_at: string
          fuseau_horaire: string
          id: string
          nom: string
          pas_creneau_minutes: number
        }
        Insert: {
          adresse?: string | null
          created_at?: string
          fuseau_horaire?: string
          id?: string
          nom: string
          pas_creneau_minutes?: number
        }
        Update: {
          adresse?: string | null
          created_at?: string
          fuseau_horaire?: string
          id?: string
          nom?: string
          pas_creneau_minutes?: number
        }
        Relationships: []
      }
      utilisateurs: {
        Row: {
          created_at: string
          email: string | null
          id: string
          nom: string
          telephone: string | null
        }
        Insert: {
          created_at?: string
          email?: string | null
          id: string
          nom: string
          telephone?: string | null
        }
        Update: {
          created_at?: string
          email?: string | null
          id?: string
          nom?: string
          telephone?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      attribuer_role: {
        Args: {
          p_role: Database["public"]["Enums"]["role"]
          p_salon: string
          p_utilisateur: string
        }
        Returns: undefined
      }
      coiffeurs_du_salon: {
        Args: { p_salon: string }
        Returns: {
          id: string
          nom: string
        }[]
      }
      creneaux_disponibles: {
        Args: {
          p_au: string
          p_coiffeur?: string
          p_du: string
          p_prestation: string
        }
        Returns: {
          coiffeur_id: string
          debut: string
          fin: string
        }[]
      }
      reserver: {
        Args: { p_coiffeur?: string; p_debut: string; p_prestation: string }
        Returns: {
          coiffeur_id: string
          debut: string
          fin: string
          id: string
        }[]
      }
    }
    Enums: {
      role: "client" | "coiffeur" | "gerant"
      statut_reservation: "confirmee" | "terminee" | "annulee" | "absent"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      role: ["client", "coiffeur", "gerant"],
      statut_reservation: ["confirmee", "terminee", "annulee", "absent"],
    },
  },
} as const

