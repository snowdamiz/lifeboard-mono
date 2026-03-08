# Phase 1: Dependency & Config - Research

**Researched:** 2026-03-07
**Domain:** Elixir/Phoenix/Ecto — adapter swap from PostgreSQL to SQLite3
**Confidence:** HIGH (all version numbers verified against hex.pm; config patterns verified against ecto_sqlite3 official docs and Fly.io Elixir guide as of project research date)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEPS-01 | Replace `postgrex` with `ecto_sqlite3 ~> 0.22` in mix.exs and remove the postgrex dependency | Full mix.exs diff documented; version confirmed at hex.pm |
| DEPS-02 | Upgrade `ecto_sql` from `~> 3.10` to `~> 3.13` (required by ecto_sqlite3 0.22.x) | ecto_sql 3.13.x is a hard requirement of ecto_sqlite3 0.22; mix.lock already resolves ecto 3.13.5 and ecto_sql 3.13.4 |
| DEPS-03 | Update `config/dev.exs` to use `Ecto.Adapters.SQLite3` with a local `.db` file path | Exact replacement config documented; path pattern uses `Path.expand` relative to config file |
| DEPS-04 | Update `config/prod.exs` and `config/runtime.exs` to use `Ecto.Adapters.SQLite3` with `DATABASE_PATH` env var | `config/prod.exs` has no DB config — only `runtime.exs` needs updating; exact replacement documented |
| DEPS-05 | Update `config/test.exs` to use `Ecto.Adapters.SQLite3` with a temp `.db` file for tests | Replacement config documented; `Ecto.Adapters.SQL.Sandbox` is compatible with SQLite in sync mode |
</phase_requirements>

---

## Summary

Phase 1 is a mechanical file-editing phase with no ambiguity. The project already has rich prior research (STACK.md, PITFALLS.md) that has been fully audited for this phase. The changes fall into three buckets: (1) swap one dependency and update one version in `mix.exs`, then run `mix deps.get`; (2) change the adapter module in `lib/mega_planner/repo.ex`; (3) replace PostgreSQL-specific Repo config blocks in four config files with SQLite equivalents.

The mix.lock file confirms that `ecto_sql` (3.13.4) and `ecto` (3.13.5) are already resolved at the 3.13 line — meaning the constraint bump from `~> 3.10` to `~> 3.13` in mix.exs will not require pulling new transitive dependencies beyond adding `ecto_sqlite3` and its `exqlite` NIF driver. The lock file does NOT yet contain `ecto_sqlite3` or `exqlite`, confirming they have not been partially installed.

The `config/prod.exs` file is intentionally empty of database configuration — all production DB config lives in `config/runtime.exs`. Only `runtime.exs` needs the `DATABASE_URL` → `DATABASE_PATH` swap. The `fly.toml` has a `release_command` entry that is out of scope for Phase 1 but is noted as a blocker for Phase 5 and should not be touched yet.

**Primary recommendation:** Apply the six targeted file edits (mix.exs, repo.ex, dev.exs, test.exs, runtime.exs, config.exs), run `mix deps.get && mix compile`, and verify the four success criteria.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `ecto_sqlite3` | `~> 0.22` | Ecto adapter for SQLite3 | The only actively-maintained Ecto 3.x SQLite adapter; wraps `exqlite` NIF; first-class `binary_id`, WAL, JSON map/array support |
| `exqlite` | pulled transitively by ecto_sqlite3 | Raw NIF-based SQLite3 driver | Do not pin directly; resolved automatically as a dep of ecto_sqlite3 |
| `ecto_sql` | `~> 3.13` | SQL query layer, migrations | Hard requirement of ecto_sqlite3 0.22.x; project currently specifies `~> 3.10` in mix.exs but mix.lock already resolves 3.13.4 |
| `ecto` | `~> 3.13` (resolved via ecto_sql) | Core data layer | Already at 3.13.5 in mix.lock; no explicit dep line needed |

### Removed

| Library | Why |
|---------|-----|
| `postgrex` | PostgreSQL-specific driver; zero use after adapter swap |

### Unchanged (already present, no action needed)

| Library | Version | Why it stays |
|---------|---------|--------------|
| `jason` | `~> 1.2` | Required by `ecto_sqlite3` for `:map`/`:array` JSON serialization; already present |
| `decimal` | `~> 2.0` | Required transitively by ecto_sqlite3; already present |
| `phoenix_ecto` | `~> 4.4` | Compatible with ecto 3.13; no change |

**Installation command (from `server/` directory):**
```bash
mix deps.get
mix deps.compile
```

---

## Architecture Patterns

### Files to Edit (complete list for Phase 1)

```
server/
├── mix.exs                          # swap postgrex -> ecto_sqlite3, bump ecto_sql
├── lib/mega_planner/repo.ex         # change adapter module
├── config/config.exs                # add migration_primary_key repo config
├── config/dev.exs                   # replace Postgres block with SQLite path config
├── config/test.exs                  # replace Postgres block with SQLite path config
└── config/runtime.exs               # replace DATABASE_URL block with DATABASE_PATH block
```

`config/prod.exs` has no database configuration — it is correct as-is and requires no changes.

### Pattern 1: mix.exs Dependency Swap

**What:** Remove `postgrex`, add `ecto_sqlite3`, bump `ecto_sql` version constraint.
**When to use:** Exactly once in this phase.

```elixir
# Source: .planning/research/STACK.md (verified against hex.pm)

# BEFORE (current mix.exs lines 30-31):
{:ecto_sql, "~> 3.10"},
{:postgrex, ">= 0.0.0"},

# AFTER:
{:ecto_sql, "~> 3.13"},
{:ecto_sqlite3, "~> 0.22"},
```

Full updated `deps/0` for reference:
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

### Pattern 2: Repo Module Adapter Change

**What:** Change the `adapter:` option in `lib/mega_planner/repo.ex`.

```elixir
# Source: hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3

# BEFORE:
defmodule MegaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :mega_planner,
    adapter: Ecto.Adapters.Postgres
end

# AFTER:
defmodule MegaPlanner.Repo do
  use Ecto.Repo,
    otp_app: :mega_planner,
    adapter: Ecto.Adapters.SQLite3
end
```

### Pattern 3: config/config.exs — Add migration_primary_key

**What:** Add a Repo config block to `config/config.exs` so that all new migrations create UUID primary keys correctly. This does NOT conflict with the per-environment config blocks in dev/test/runtime.exs.

```elixir
# Source: .planning/research/STACK.md

# ADD after the existing config :mega_planner block:
config :mega_planner, MegaPlanner.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime]
```

The existing line `generators: [timestamp_type: :utc_datetime, binary_id: true]` already exists and is correct — no changes needed there.

### Pattern 4: config/dev.exs — Replace PostgreSQL Block

**What:** Remove PostgreSQL credentials; set SQLite file path relative to the config directory.

```elixir
# Source: .planning/research/STACK.md + hexdocs.pm/ecto_sqlite3

# REMOVE (current dev.exs lines 3-10):
config :mega_planner, MegaPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mega_planner_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# REPLACE WITH:
config :mega_planner, MegaPlanner.Repo,
  database: Path.expand("../mega_planner_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  show_sensitive_data_on_connection_error: true,
  stacktrace: true
```

Note: `Path.expand("../mega_planner_dev.db", Path.dirname(__ENV__.file))` places the `.db` file at `server/mega_planner_dev.db` — next to `mix.exs`. This is the standard community pattern.

### Pattern 5: config/test.exs — Replace PostgreSQL Block

**What:** Remove PostgreSQL credentials; set a dedicated SQLite test database path.

```elixir
# Source: .planning/research/STACK.md + hexdocs.pm/ecto_sqlite3

# REMOVE (current test.exs lines 3-9):
config :mega_planner, MegaPlanner.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mega_planner_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# REPLACE WITH:
config :mega_planner, MegaPlanner.Repo,
  database: Path.expand("../mega_planner_test.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox
```

**Critical note:** `MIX_TEST_PARTITION` sharding does not apply to SQLite (only one file per test run). The test database file will be `server/mega_planner_test.db`.

### Pattern 6: config/runtime.exs — Replace DATABASE_URL Block

**What:** Remove the `DATABASE_URL` fetch-and-raise block and PostgreSQL socket options; replace with `DATABASE_PATH`.

```elixir
# Source: .planning/research/STACK.md + fly.io/docs/elixir/advanced-guides/sqlite3/

# REMOVE (current runtime.exs lines 69-81):
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

# REPLACE WITH (inside the existing `if config_env() == :prod do` block):
database_path =
  System.get_env("DATABASE_PATH") ||
    raise """
    environment variable DATABASE_PATH is missing.
    Set it to the SQLite file path on the persistent volume.
    For example: /data/lifeboard.db
    """

config :mega_planner, MegaPlanner.Repo,
  database: database_path,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")
```

The `maybe_ipv6`/`socket_options` block is PostgreSQL-specific (network socket concept); remove it entirely.

### Anti-Patterns to Avoid

- **Leaving `postgrex` in mix.exs:** Even if unused, it will still compile and may cause `Ecto.Adapters.Postgres` to remain loadable, creating false confidence during compile check.
- **Setting `pool_size: 10` for SQLite:** SQLite WAL mode allows many readers but only one writer. Pool size > 5 provides no benefit and increases write contention. The existing test config has `pool_size: 10` — must be reduced.
- **Removing `pool: Ecto.Adapters.SQL.Sandbox` from test.exs:** The sandbox is still required for test isolation in SQLite; it wraps each test in a transaction that gets rolled back. Keep the pool declaration.
- **Touching `config/prod.exs`:** That file has no database configuration and must not be touched.
- **Touching `fly.toml` or `release_command`:** That is Phase 5 scope.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite connection pooling | Custom pool logic | `ecto_sqlite3` built-in pool with `pool_size: 5` | SQLite WAL handles concurrency at file level; pool just queues writes |
| UUID generation for SQLite | Custom UUID gen function | `autogenerate: true` in schema (already set globally) | Ecto generates UUIDs in the application layer; no DB function needed |
| JSON serialization for `:map` fields | Custom type or encoding step | `ecto_sqlite3` default `map_type: :string` | Adapter serializes/deserializes automatically; no schema changes needed |
| Database file path resolution | Hardcoded absolute paths | `Path.expand("../file.db", Path.dirname(__ENV__.file))` | Works correctly across developer machines and CI; idiomatic Elixir |

**Key insight:** The adapter swap is purely a configuration change. The Ecto DSL (schemas, changesets, queries) does not change in Phase 1. All application code changes are deferred to Phase 3.

---

## Common Pitfalls

### Pitfall 1: mix.lock Conflicts After Dependency Swap

**What goes wrong:** After removing `postgrex` and adding `ecto_sqlite3`, running `mix deps.get` may produce lock file conflicts if any transitive dependency previously pinned by `postgrex` is no longer needed, or if `exqlite` (the NIF) requires a different version of a shared dep.

**Why it happens:** `postgrex` and `ecto_sqlite3` share `db_connection` as a transitive dep. The versions must be compatible.

**How to avoid:** Run `mix deps.get` and inspect the output for any dependency resolution warnings. If there are conflicts, run `mix deps.update --all` after the swap and verify the lockfile resolves cleanly. The existing `db_connection 2.8.1` in the lock is compatible with ecto_sqlite3 0.22.

**Warning signs:** `mix deps.get` prints "dependency conflict" or "could not resolve"; `mix compile` reports undefined module warnings.

### Pitfall 2: `Ecto.Adapters.Postgres` Still Referenced in Compiled Beam Files

**What goes wrong:** After changing `repo.ex`, an old `.beam` file for `MegaPlanner.Repo` may persist with the old adapter. `mix compile` may not detect the change if the source file modification time is incorrect.

**How to avoid:** Run `mix compile --force` after changing `repo.ex` to guarantee recompilation. Verify with `mix compile 2>&1 | grep -i warn`.

### Pitfall 3: `.db` File Created in Wrong Directory

**What goes wrong:** If `Path.expand` is given a relative path without the `Path.dirname(__ENV__.file)` anchor, the `.db` file is created relative to the current working directory when Mix is invoked — not relative to the config file. Running `mix ecto.create` from different directories produces different file locations.

**How to avoid:** Always use the two-argument form: `Path.expand("../mega_planner_dev.db", Path.dirname(__ENV__.file))`. This anchors the relative path to the config file's location, which is stable regardless of the working directory.

**Warning signs:** Running `mix ecto.create && mix ecto.migrate` succeeds but `ls server/*.db` shows no file; the file is in an unexpected location.

### Pitfall 4: `async: true` Tests Will Fail with SQLite

**What goes wrong:** Existing tests use `use ExUnit.Case, async: true` and `Ecto.Adapters.SQL.Sandbox` — confirmed in `receipt_parsing_test.exs` (line 11) and `bug_repro_test.exs` (line 6). SQLite allows only one writer at a time. With `async: true`, two tests writing simultaneously cause `(Exqlite.Error) Database busy` / `SQLITE_BUSY`.

**Why it happens:** SQLite's WAL mode serializes writers at the file level. The Sandbox's shared mode spawns concurrent transactions from different test processes.

**How to avoid:** This is explicitly CODE-02 (Phase 3 scope). The config changes in Phase 1 make the test file structurally correct (sandbox pool, correct path) but the `async: true` in individual test modules is fixed in Phase 3. Phase 1 verification should run `mix compile` only — not `mix test`.

**Warning signs:** After Phase 1, `mix test` may fail with Database busy errors. This is expected and addressed in Phase 3.

### Pitfall 5: `pool_size: 1` vs `pool_size: 5` Ambiguity

**What goes wrong:** The project STATE.md notes a research gap: PITFALLS.md recommends `pool_size: 1` and STACK.md recommends `pool_size: 5`.

**Resolution:** Use `pool_size: 5` as the default for dev/test (STACK.md's recommendation). The PITFALLS.md note about `pool_size: 1` applies specifically to production under concurrent write load. In Phase 1, set `pool_size: 5` in all environments. Production pool size validation is deferred to Phase 3 (STATE.md decision).

---

## Code Examples

### Verifying the Adapter Module After Compile

```bash
# Source: standard Elixir debugging pattern
# After mix compile, confirm the adapter module loads correctly:
mix run --no-start -e "IO.inspect(MegaPlanner.Repo.__adapter__())"
# Expected output: Ecto.Adapters.SQLite3
```

### Verifying the Database File Is Created Correctly

```bash
# From server/ directory, after mix ecto.create:
ls -la mega_planner_dev.db
# File should exist at server/mega_planner_dev.db

sqlite3 mega_planner_dev.db ".tables"
# At this point (before Phase 2 migrations) output will be empty or
# show only schema_migrations — this is correct
```

### Verifying No PostgreSQL References Remain

```bash
# Run from server/ directory:
grep -rn "Postgres\|postgrex\|DATABASE_URL\|pool_size: 10" config/
grep -rn "Ecto.Adapters.Postgres\|postgrex" lib/mega_planner/repo.ex mix.exs
```

### Checking Deps After mix deps.get

```bash
mix deps | grep -E "ecto_sqlite3|postgrex|ecto_sql|exqlite"
# Expected:
#   ecto_sqlite3 0.22.x  (ok)
#   ecto_sql 3.13.x      (ok)
#   exqlite 0.x          (ok, pulled by ecto_sqlite3)
# postgrex should NOT appear
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `postgrex` + `Ecto.Adapters.Postgres` | `ecto_sqlite3` + `Ecto.Adapters.SQLite3` | This phase | Enables local file-based DB; removes PostgreSQL network dependency |
| `DATABASE_URL` (Ecto URI) | `DATABASE_PATH` (file path string) | This phase | Simpler prod config; works with Fly.io volume mount at `/data` |
| `pool_size: 10` | `pool_size: 5` | This phase | Appropriate for SQLite's single-writer model; prevents SQLITE_BUSY under load |
| `username/password/hostname` in config | No credentials; just `database:` path | This phase | SQLite is an embedded file DB; no network auth layer exists |

**Note:** `ecto_sql` was already at version 3.13.x in the mix.lock despite the `~> 3.10` constraint in mix.exs. The constraint change in mix.exs is a documentation-accuracy fix as much as a functional one.

---

## Open Questions

1. **`mix.lock` postgrex entry cleanup**
   - What we know: `postgrex 0.21.1` is in mix.lock and will remain there after `mix deps.get` until explicitly cleaned
   - What's unclear: Does a stale `postgrex` entry in mix.lock cause compile warnings or `mix deps.check` failures?
   - Recommendation: Run `mix deps.clean postgrex --build` after `mix deps.get` to remove compiled artifacts; the lock entry will be pruned automatically when `mix deps.get` regenerates the lockfile without it.

2. **`phoenix_ecto` optional `postgrex` dependency**
   - What we know: `phoenix_ecto 4.7.0` lists `postgrex` as an optional dependency (visible in mix.lock entry)
   - What's unclear: Does removing `postgrex` cause any optional code path in `phoenix_ecto` to fail at compile time?
   - Recommendation: LOW risk — optional deps in Hex are compile-time excluded when absent. Verify `mix compile` succeeds with zero warnings. If any warning appears, it will be a clear signal.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir, no version pin needed) |
| Config file | `server/test/test_helper.exs` (exists) |
| Quick run command | `cd server && mix compile --warnings-as-errors` |
| Full suite command | `cd server && mix test` (deferred — async: true issue in Phase 3) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEPS-01 | `postgrex` absent, `ecto_sqlite3` present in dep tree | smoke | `mix deps \| grep -E "ecto_sqlite3\|postgrex"` | ✅ (grep check) |
| DEPS-02 | `ecto_sql` resolves to 3.13.x | smoke | `mix deps \| grep ecto_sql` | ✅ (grep check) |
| DEPS-03 | `dev.exs` references `Ecto.Adapters.SQLite3`; no PostgreSQL config | smoke | `grep -rn "SQLite3\|postgres" server/config/dev.exs` | ✅ (grep check) |
| DEPS-04 | `runtime.exs` uses `DATABASE_PATH`; no `DATABASE_URL` | smoke | `grep -rn "DATABASE_PATH\|DATABASE_URL" server/config/runtime.exs` | ✅ (grep check) |
| DEPS-05 | `test.exs` uses `Ecto.Adapters.SQLite3` path config | smoke | `grep -rn "SQLite3\|postgres" server/config/test.exs` | ✅ (grep check) |

All Phase 1 requirements are verifiable with `mix compile` and grep checks. No new test files are needed.

### Sampling Rate

- **Per task commit:** `cd server && mix compile`
- **Per wave merge:** `cd server && mix compile --warnings-as-errors && mix deps | grep -E "ecto_sqlite3|postgrex|ecto_sql"`
- **Phase gate:** `mix compile` succeeds with zero warnings AND `mix ecto.create` creates `server/mega_planner_dev.db` successfully

### Wave 0 Gaps

None — existing test infrastructure covers all phase requirements. Phase 1 verification is compile-time and grep-based, not runtime test-based.

---

## Sources

### Primary (HIGH confidence)

- `.planning/research/STACK.md` — Complete config diffs for all six files; version matrix; ecto_sqlite3 adapter config reference (verified against hex.pm and hexdocs as of 2026-03-07)
- `.planning/research/PITFALLS.md` — Pitfalls 1-8 with specific file locations in this codebase; pool_size ambiguity documented
- `server/mix.lock` — Confirms ecto_sql 3.13.4 and ecto 3.13.5 already resolved; postgrex 0.21.1 present and to be removed; no ecto_sqlite3 or exqlite present yet
- `server/mix.exs` — Confirms current `postgrex ">= 0.0.0"` and `ecto_sql "~> 3.10"` as starting state
- `server/config/runtime.exs` — Confirms `DATABASE_URL` block location (lines 69-81) for exact surgical removal
- `server/config/dev.exs` — Confirms PostgreSQL credentials block (lines 3-10) for replacement
- `server/config/test.exs` — Confirms PostgreSQL credentials block (lines 3-9) and `async: true` test pattern
- [hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3](https://hexdocs.pm/ecto_sqlite3/Ecto.Adapters.SQLite3.html) — Adapter configuration options and defaults (HIGH confidence)
- [fly.io/docs/elixir/advanced-guides/sqlite3/](https://fly.io/docs/elixir/advanced-guides/sqlite3/) — Production runtime.exs pattern, DATABASE_PATH, pool_size recommendation (HIGH confidence)

### Secondary (MEDIUM confidence)

- `server/test/mega_planner/receipt_parsing_test.exs` and `bug_repro_test.exs` — Confirms `async: true` usage; documents the Phase 3 async problem that will surface after Phase 1 config changes

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — versions confirmed against mix.lock and hex.pm; no speculation
- Architecture: HIGH — exact file diffs documented from codebase audit and prior STACK.md research
- Pitfalls: HIGH — async issue confirmed by reading actual test files; pool_size ambiguity documented from STATE.md

**Research date:** 2026-03-07
**Valid until:** 2026-06-07 (ecto_sqlite3 0.22.x is stable; Fly.io guide patterns are stable; 90-day estimate)
