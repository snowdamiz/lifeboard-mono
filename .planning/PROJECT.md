# Lifeboard: PostgreSQL → SQLite Migration

## What This Is

Lifeboard is a Phoenix/Elixir + Vue 3 household management app currently backed by PostgreSQL on Fly.io. This project migrates the entire data layer from PostgreSQL to SQLite (single Fly.io volume), preserving all production data. The goal is to eliminate the managed PostgreSQL dependency, simplify deployment, and reduce hosting costs while keeping the app fully functional.

## Core Value

All production data survives the migration intact — zero data loss is the non-negotiable constraint that drives every decision.

## Requirements

### Validated

- ✓ Phoenix/Ecto backend serving REST API — existing
- ✓ Household-based multi-tenant data model — existing
- ✓ JWT authentication via Guardian/Ueberauth — existing
- ✓ Fly.io deployment via Docker — existing

### Active

- [ ] Audit all migrations and schemas for PostgreSQL-specific types (arrays, jsonb, maps, raw SQL)
- [ ] Replace `postgrex` driver with `ecto_sqlite3` (or `exqlite`)
- [ ] Update all Ecto config files (dev, prod, runtime) for SQLite adapter
- [ ] Rewrite migrations to be SQLite-compatible (array → JSON text, jsonb → :text, gen_random_uuid → Ecto-managed UUIDs)
- [ ] Update Ecto schemas where array/jsonb types are declared
- [ ] Export all production data from PostgreSQL
- [ ] Transform and import data into SQLite (handle UUID encoding, JSON serialization of arrays)
- [ ] Configure Fly.io persistent volume for SQLite file
- [ ] Update fly.toml and Dockerfile for SQLite deployment
- [ ] Verify application functions correctly against SQLite in development
- [ ] Run full migration against production data, validate record counts and integrity
- [ ] Deploy to Fly.io and smoke test

### Out of Scope

- LiteFS / distributed SQLite replication — single volume is sufficient for a personal household app
- Turso / libSQL — adding a managed service defeats the simplification goal
- Changing application features — this is a database swap, not a feature change
- Moving away from Fly.io — deployment target stays the same

## Context

**Schema complexity:** ~30 tables across domains: users, households, tasks, budget, inventory, goals, habits, notes, shopping lists, stores, trips, purchases, notifications, tags. All use UUID primary keys.

**PostgreSQL-specific issues identified:**
- `{:array, :string}` — `default_steps` (task_templates), `nav_order` (user_preferences), `tags` (budget)
- `{:array, :integer}` — `days_of_week` (habits)
- `{:array, :binary_id}` — `linked_task_ids` (goals), `linked_inventory_ids` (habits), `default_tags` (brands)
- `:jsonb` — `dashboard_widgets`, `settings` (user_preferences)
- `:map` — `recurrence_rule` (tasks, budget), `push_subscription`, `data` (notifications), `columns`, `custom_fields` (inventory), `preference_notes`, etc.
- Raw `gen_random_uuid()` SQL call in migration `20260101000013_add_household_id_to_data_tables.exs`

**Data migration approach:** Export via `pg_dump` or Ecto scripts → transform → import to SQLite. Arrays and maps stored as JSON text in SQLite. UUID values remain as strings.

**Fly.io deployment:** Switch from `DATABASE_URL` pointing to PostgreSQL to a mounted volume path. SQLite file lives at `/data/lifeboard.db` on a persistent Fly volume.

## Constraints

- **Data**: Zero data loss — production data must migrate completely and verifiably
- **Downtime**: Migration will require a brief maintenance window (coordinated cutover)
- **Ecto**: Must use `ecto_sqlite3` (actively maintained Ecto adapter for SQLite3) — not `exqlite` directly
- **SQLite**: Arrays and JSONB must be stored as JSON text; application query code that uses array containment operators won't work and must be replaced with alternative logic
- **Fly.io**: SQLite file must be on a persistent volume — cannot use ephemeral storage

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single Fly volume (not LiteFS) | Personal household app, single-writer is fine, LiteFS adds significant ops complexity | — Pending |
| `ecto_sqlite3` adapter | Most actively maintained SQLite adapter for Ecto, good community support | — Pending |
| Arrays → JSON text | SQLite has no native array type; JSON text is the standard workaround in Ecto SQLite | — Pending |
| Export via Elixir scripts (not pg_dump) | Elixir scripts give full control over UUID encoding and type coercion for SQLite | — Pending |

---
*Last updated: 2026-03-07 after initialization*
