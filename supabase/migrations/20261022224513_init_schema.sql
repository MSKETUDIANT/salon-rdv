-- Issue #1 : schéma initial de salon-rdv.
-- 2 enums, 9 tables, contrainte d'exclusion anti-chevauchement des réservations.

-- btree_gist : permet de combiner "=" (uuid) et "&&" (plage) dans un même index GiST.
create extension if not exists btree_gist with schema extensions;

-- ============================================================
-- Enums
-- ============================================================

create type public.role as enum ('client', 'coiffeur', 'gerant');

create type public.statut_reservation as enum ('confirmee', 'terminee', 'annulee', 'absent');

-- ============================================================
-- Tables
-- ============================================================

create table public.salons (
  id         uuid primary key default gen_random_uuid(),
  nom        varchar not null,
  adresse    varchar,
  created_at timestamptz not null default now()
);

-- Sera relié à auth.users dans l'issue authentification et rôles.
create table public.utilisateurs (
  id         uuid primary key default gen_random_uuid(),
  nom        varchar not null,
  telephone  varchar unique,
  email      varchar unique,
  created_at timestamptz not null default now()
);

create table public.roles_utilisateur (
  utilisateur_id uuid not null references public.utilisateurs (id),
  salon_id       uuid not null references public.salons (id),
  role           public.role not null,
  primary key (utilisateur_id, salon_id, role)
);

create table public.prestations (
  id            uuid primary key default gen_random_uuid(),
  salon_id      uuid not null references public.salons (id),
  nom           varchar not null,
  prix          numeric(12, 3) not null,
  duree_minutes integer not null,
  active        boolean not null default true,
  constraint prestations_prix_positif check (prix >= 0),
  constraint prestations_duree_positive check (duree_minutes > 0)
);

create table public.competences (
  coiffeur_id   uuid not null references public.utilisateurs (id),
  prestation_id uuid not null references public.prestations (id),
  primary key (coiffeur_id, prestation_id)
);

create table public.horaires (
  id           uuid primary key default gen_random_uuid(),
  salon_id     uuid not null references public.salons (id),
  coiffeur_id  uuid not null references public.utilisateurs (id),
  jour_semaine integer not null, -- 1 = lundi ... 7 = dimanche
  heure_debut  time not null,
  heure_fin    time not null,
  constraint horaires_jour_valide check (jour_semaine between 1 and 7),
  constraint horaires_plage_valide check (heure_fin > heure_debut)
);

create table public.absences (
  id          uuid primary key default gen_random_uuid(),
  salon_id    uuid not null references public.salons (id),
  coiffeur_id uuid not null references public.utilisateurs (id),
  debut       timestamptz not null,
  fin         timestamptz not null,
  motif       varchar,
  constraint absences_plage_valide check (fin > debut)
);

create table public.reservations (
  id            uuid primary key default gen_random_uuid(),
  salon_id      uuid not null references public.salons (id),
  client_id     uuid not null references public.utilisateurs (id),
  coiffeur_id   uuid not null references public.utilisateurs (id),
  prestation_id uuid not null references public.prestations (id),
  debut         timestamptz not null,
  fin           timestamptz not null,
  statut        public.statut_reservation not null default 'confirmee',
  created_at    timestamptz not null default now(),
  constraint reservations_plage_valide check (fin > debut),
  -- Zéro double réservation (BNF-1) : un coiffeur ne peut pas avoir deux
  -- réservations non annulées qui se chevauchent. '[)' : bout à bout autorisé.
  constraint reservations_sans_chevauchement exclude using gist (
    coiffeur_id with =,
    tstzrange(debut, fin, '[)') with &&
  ) where (statut <> 'annulee')
);

create table public.encaissements (
  id             uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.reservations (id),
  montant        numeric(12, 3) not null,
  encaisse_par   uuid references public.utilisateurs (id),
  created_at     timestamptz not null default now(),
  constraint encaissements_montant_positif check (montant >= 0)
);

-- ============================================================
-- RLS : activée partout, sans policy (tout refusé via l'API).
-- Les policies viendront dans l'issue dédiée aux règles d'accès.
-- ============================================================

alter table public.salons            enable row level security;
alter table public.utilisateurs      enable row level security;
alter table public.roles_utilisateur enable row level security;
alter table public.prestations       enable row level security;
alter table public.competences       enable row level security;
alter table public.horaires          enable row level security;
alter table public.absences          enable row level security;
alter table public.reservations      enable row level security;
alter table public.encaissements     enable row level security;
