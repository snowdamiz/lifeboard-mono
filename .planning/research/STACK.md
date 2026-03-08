# Stack Research

**Domain:** Elixir/Phoenix + Ecto — PostgreSQL to SQLite migration
**Researched:** 2026-03-07
**Confidence:** HIGH (all versions verified against hex.pm and hexdocs as of research date)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `ecto_sqlite3` | `~> 0.22` | Ecto adapter for SQLite3 | The only actively-maintained Ecto 3.x SQLite adapter. Built by the same team as exqlite. Has first-class support for binary_id, WAL mode, JSON maps/arrays, and type extensions. Do not use exqlite directly — it is the low-level driver that ecto_sqlite3 wraps. |
| `exqlite` | `~> 0.22` (pulled in transitively) | NIF-based SQLite3 driver | Pulled in automatically as a dependency of ecto_sqlite3. Do not pin this directly unless you need a specific NIF build. Current latest is 0.35.0 (Feb 2026). |
| `ecto_sql` | `~> 3.13` | SQL query layer, migrations | ecto_sqlite3 0.22.x requires exactly `~> 3.13.0`. Current project uses `~> 3.10` — must upgrade. Latest is 3.13.5 (Mar 3 2026). |
| `ecto` | `~> 3.13` | Core data layer | Required by ecto_sql 3.13 and ecto_sqlite3 0.22. Current project uses `~> 3.10` — must upgrade. Latest is 3.13.5 (Mar 2026). |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jason` | `~> 1.2` (already present) | JSON encoding/decoding | Required by ecto_sqlite3 for map/array type serialization. Already in deps, no change needed. |
| `decimal` | `~> 2.0` (already present) | Decimal type support | Required transitively by ecto_sqlite3. Already present via ecto. |

### Libraries to Remove

| Library | Why |
|---------|-----|
| `postgrex` | PostgreSQL-specific driver. Completely replaced by ecto_sqlite3 + exqlite. Remove entirely from deps and all config references. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `mix ecto.create` | Creates the `.db` file | Works unchanged; creates the SQLite file at the configured path. |
| `mix ecto.migrate` | Runs migrations | Works unchanged; SQLite-specific migration constraints apply (see Pitfalls). |
| `mix ecto.drop` | Deletes the `.db` file | Works unchanged. |
| `sqlite3` CLI | Inspect database directly | `sqlite3 /path/to/dev.db` for direct SQL queries, validation, and debugging during migration. |

---

## Version Compatibility Matrix

| Package | Required Version | Current in Project | Action |
|---------|-----------------|-------------------|--------|
| `ecto_sqlite3` | `~> 0.22` | not present | Add |
| `postgrex` | remove | `>= 0.0.0` | Remove |
| `ecto_sql` | `~> 3.13` | `~> 3.10` | Upgrade |
| `ecto` | `~> 3.13` | (implicit via ecto_sql) | Upgrade via lockfile update |
| `phoenix_ecto` | `~> 4.4` (already present) | `~> 4.4` | Keep — compatible |
| `elixir` | `~> 1.14` min (ecto_sql requirement) | `~> 1.15` | No change needed |

---

## Configuration Changes

### mix.exs

**Remove:**
```elixir
{:postgrex, ">= 0.0.0"},
```

**Add:**
```elixir
{:ecto_sqlite3, "~> 0.22"},
```

**Upgrade (version constraint change only — hex will resolve latest 3.13.x):**
```elixir
{:ecto_sql, "~> 3.13"},
```

The full updated `deps/0` section:
```elixir
defp deps do
  [
    {:phoenix, "~> 1.7.10"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.13"},
    {:ecto_sqlite3, "~> 0.22"},
    {:phoenix_live_dashboard, "~> 0.8.2"},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:jason, "~> 1.2"},
    {:plug_cowboy, "~> 2.5"},
    {:cors_plug, "~> 3.0"},

    # Authentication
    {:ueberauth, "~> 0.10"},
    {:ueberauth_google, "~> 0.12"},
    {:guardian, "~> 2.3"},

    # Utilities
    {:timex, "~> 3.7"},
    {:decimal, "~> 2.0"},
    {:dotenvy, "~> 0.8.0"},

    # Dev/Test
    {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    {:swoosh, "~> 1.3"},
    {:finch, "~> 0.13"}
  ]
end
```

After updating, run:
```bash
mix deps.get
mix deps.compile
```

---

### lib/mega_planner/repo.ex

**Before:**
```elixir
defmodule MegaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :mega_planner,
    adapter: Ecto.Adapters.Postgres
end
```

**After:**
```elixir
defmodule MegaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :mega_planner,
    adapter: Ecto.Adapters.SQLite3
end
```

---

### config/config.exs

The existing `generators` line already has `binary_id: true`. Add `migration_primary_key` to ensure migrations create UUID primary keys correctly (SQLite has no native UUID type; Ecto generates them):

**Before:**
```elixir
config :mega_planner,
  ecto_repos: [MegaPlanner.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  frontend_url: "http://localhost:5173"
```

**After:**
```elixir
config :mega_planner,
  ecto_repos: [MegaPlanner.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  frontend_url: "http://localhost:5173"

config :mega_planner, MegaPlanner.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime]
```

No other changes to `config.exs` are needed.

---

### config/dev.exs

**Remove** the entire PostgreSQL block:
```elixir
# REMOVE THIS:
config :mega_planner, MegaPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mega_planner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

**Replace with:**
```elixir
config :mega_planner, MegaPlanner.Repo,
  database: Path.expand("../mega_planner_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true,
  stacktrace: true
```

Notes:
- `Path.expand` places `mega_planner_dev.db` in the `server/` project root, next to `mix.exs`. This is the standard pattern used by the Fly.io docs and ecto_sqlite3 community.
- `pool_size: 5` is the SQLite-appropriate default (SQLite does not benefit from large pools — WAL mode handles concurrency at the file level, not the connection level).
- No `username`, `password`, `hostname`, or `database` name needed.

---

### config/test.exs

**Remove** the PostgreSQL block:
```elixir
# REMOVE THIS:
config :mega_planner, MegaPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mega_planner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
```

**Replace with:**
```elixir
config :mega_planner, MegaPlanner.Repo,
  database: Path.expand("../mega_planner_test.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox
```

**Critical caveat:** ecto_sqlite3 does NOT support async tests with `Ecto.Adapters.SQL.Sandbox`. SQLite allows only one write transaction at a time. All tests must use `async: false`. If the project uses `async: true` anywhere, those tests must be changed to `async: false`. Failure to do this causes intermittent deadlocks and mysterious test failures.

---

### config/prod.exs

No database configuration is in `prod.exs` currently (correct — all prod DB config is in `runtime.exs`). No changes required here.

---

### config/runtime.exs

This is the most significant change for production.

**Remove** the entire DATABASE_URL PostgreSQL block:
```elixir
# REMOVE THIS:
database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

config :mega_planner, MegaPlanner.Repo,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6
```

**Replace with:**
```elixir
database_path =
  System.get_env("DATABASE_PATH") ||
    raise """
    environment variable DATABASE_PATH is missing.
    Set it to the SQLite file path on the persistent volume.
    For example: /data/lifeboard/lifeboard.db
    """

config :mega_planner, MegaPlanner.Repo,
  database: database_path,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
```

The `maybe_ipv6`/`socket_options` block is PostgreSQL-specific and must be removed entirely. SQLite has no network socket.

---

### fly.toml Changes

**Remove** any `[deploy]` `release_command` if present (SQLite volumes may not be ready when release commands run):
```toml
# REMOVE if present:
[deploy]
  release_command = "/app/bin/migrate"
```

**Add** volume mount and environment variable:
```toml
[mounts]
  source = "lifeboard_data"
  destination = "/data"

[env]
  DATABASE_PATH = "/data/lifeboard/lifeboard.db"
```

Notes:
- The volume source name (`lifeboard_data`) must match the name used when you run `fly volumes create lifeboard_data --size 1 --region [your-region]`.
- The destination `/data` is the mount point. The actual `.db` file path is `/data/lifeboard/lifeboard.db` — the subdirectory ensures the directory exists before the file is created.
- Fly.io volumes are scoped to a single machine/region. Multi-region deployment is not possible without LiteFS (explicitly out of scope per PROJECT.md).

---

### Application Start — Migration Handling

Because SQLite volumes may not be mounted when Fly's `release_command` runs, migrations must run at application startup instead.

**File: `lib/mega_planner/release.ex`** (create if it does not exist, or update if it does):
```elixir
defmodule MegaPlanner.Release do
  @app :mega_planner

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
```

**File: `lib/mega_planner/application.ex`** — add migrate call at the top of `start/2`:
```elixir
def start(_type, _args) do
  if Application.get_env(:mega_planner, :env) == :prod do
    MegaPlanner.Release.migrate()
  end

  children = [
    # ... existing children
  ]
  # ... existing supervisor
end
```

Alternative: call `MegaPlanner.Release.migrate()` unconditionally — it is idempotent (Ecto tracks which migrations have run). The env guard is optional but keeps dev startup clean.

---

## UUID / binary_id Handling

**Background:** PostgreSQL stores UUIDs as a native 16-byte type. SQLite has no UUID type — ecto_sqlite3 stores them as TEXT (36-character string, e.g., `"550e8400-e29b-41d4-a716-446655440000"`) by default.

**Why this is safe for this project:**
- All schemas already declare `@primary_key {:id, :binary_id, autogenerate: true}` (set globally via `generators: [binary_id: true]`).
- `autogenerate: true` means Ecto generates UUIDs in the application layer — no dependency on `gen_random_uuid()` or any database function. This is correct for SQLite.
- The raw `gen_random_uuid()` call in migration `20260101000013_add_household_id_to_data_tables.exs` must be replaced. Replace with a static default of `nil` or use a data migration script — SQLite cannot call PostgreSQL functions.

**Recommended adapter config for UUID (add to repo config in all environments):**

The defaults are already correct for this project:
- `:binary_id_type` defaults to `:string` — UUIDs stored as TEXT. This matches what the data export will produce (string UUIDs).
- `:uuid_type` defaults to `:string` — same.

No explicit override needed unless you want binary storage (not recommended for this project because it complicates the data migration and SQLite inspection).

**Foreign key UUID references:** SQLite enforces `:foreign_keys` by default in ecto_sqlite3. Since all foreign keys in this project reference UUID primary keys stored as TEXT, this works correctly.

---

## ecto_sqlite3 Adapter Configuration Reference

All of these can be set in the repo config block. Shown with their defaults and notes for this project:

```elixir
config :mega_planner, MegaPlanner.Repo,
  database: "/path/to/db",       # required — no default
  pool_size: 5,                  # default: 5 — appropriate for SQLite
  journal_mode: :wal,            # default: :wal — do not change, WAL is vastly better for concurrent reads
  temp_store: :memory,           # default: :memory — fine
  cache_size: -64_000,           # default: -64000 (KB) — 64MB cache, fine for this app
  busy_timeout: 2000,            # default: 2000ms — increase to 5000 in prod if you see lock timeouts
  foreign_keys: :on,             # default: :on — keep on for relational integrity
  synchronous: :normal,          # default: :normal — safe, good performance balance
  binary_id_type: :string,       # default: :string — keep, matches data migration output
  uuid_type: :string,            # default: :string — keep
  map_type: :string,             # default: :string — JSON text, fine for :map/:jsonb fields
  array_type: :string,           # default: :string — JSON text, required (no native array type)
  datetime_type: :iso8601        # default: :iso8601 — keep
```

For production, you do not need to explicitly set all of these — only override what you need. The minimal production config is:

```elixir
config :mega_planner, MegaPlanner.Repo,
  database: database_path,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `ecto_sqlite3 ~> 0.22` | `exqlite` directly | Never for Phoenix/Ecto apps — exqlite is the raw NIF driver, not an Ecto adapter. ecto_sqlite3 is the correct abstraction layer. |
| `ecto_sqlite3 ~> 0.22` | `sqlite_ecto2` | Only for Ecto 2.x apps (legacy, abandoned). This project uses Ecto 3.x. |
| Single Fly volume | LiteFS | Only if you need multi-region writes. LiteFS adds operational complexity (FUSE filesystem, Consul, distributed consensus). Out of scope per PROJECT.md. |
| Single Fly volume | Turso/libSQL | Only if you need a managed SQLite service. Defeats the simplification goal. Out of scope per PROJECT.md. |
| `binary_id_type: :string` | `binary_id_type: :binary` | Only if you care about raw storage size (16 bytes vs 36 bytes per UUID). Binary mode makes direct DB inspection harder and complicates the data migration. Avoid for this project. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `postgrex` | PostgreSQL driver — not applicable to SQLite | `ecto_sqlite3` |
| `gen_random_uuid()` in migrations | PostgreSQL-specific SQL function — SQLite will error | Remove from migrations; let `autogenerate: true` generate UUIDs in Elixir |
| `{:array, :string}` / `{:array, :binary_id}` Ecto types | PostgreSQL array types — not supported in SQLite | Use `:string` with JSON serialization via a custom Ecto type or embedded schema. The adapter's `array_type: :string` handles this automatically for schema-declared arrays. |
| `:jsonb` Ecto type | PostgreSQL-specific — maps to JSONB binary format | Use `:map` instead; ecto_sqlite3 serializes `:map` as JSON text automatically. |
| `Ecto.Adapters.SQL.Sandbox` with `async: true` | SQLite allows only one write transaction; async tests cause deadlocks | Use `async: false` for all tests |
| `release_command` in fly.toml for migrations | Volume may not be mounted when release command runs | Run migrations in `Application.start/2` |
| Large `pool_size` | SQLite WAL mode allows multiple readers but only one writer; extra connections queue on writes | Keep `pool_size: 5` — tuning higher does not help throughput |

---

## Sources

- [ecto_sqlite3 hex.pm package](https://hex.pm/packages/ecto_sqlite3) — version 0.22.0 verified current as of Sep 25 2025; exqlite 0.35.0 as of Feb 25 2026 (HIGH confidence)
- [Ecto.Adapters.SQLite3 hexdocs v0.22.0](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html) — all config options, defaults, limitations (HIGH confidence)
- [Fly.io SQLite3 Guide](https://fly.io/docs/elixir/advanced-guides/sqlite3/) — volume setup, runtime.exs pattern, release_command caveat, APPLICATION.start migration pattern (HIGH confidence)
- [Phoenix + SQLite Deployment Tips gist (mcrumm)](https://gist.github.com/mcrumm/98059439c673be7e0484589162a54a01) — production config patterns, fly.toml structure (MEDIUM confidence)
- [ecto_sqlite3 issue #70 — binary_id_type configuration](https://github.com/elixir-sqlite/ecto_sqlite3/issues/70) — binary_id_type and uuid_type option behavior (HIGH confidence)
- [ecto_sql hex.pm](https://hex.pm/packages/ecto_sql) — latest version 3.13.5 verified as of Mar 3 2026 (HIGH confidence)

---

*Stack research for: Elixir/Phoenix PostgreSQL → SQLite migration (Fly.io)*
*Researched: 2026-03-07*
