# Phase 5: Fly.io Deployment & Cutover — Research

**Researched:** 2026-03-08
**Domain:** Fly.io volumes, Elixir releases, SQLite persistent storage, production cutover
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DEPL-01 | Create a persistent Fly.io volume for the SQLite database file (e.g., `lifeboard_data`, mounted at `/data`) | Fly CLI `fly volumes create` command documented; volume must match app region (iad) |
| DEPL-02 | Update `fly.toml` — remove `release_command`, add volume mount configuration | `[mounts]` section syntax confirmed; `release_command` documented as incompatible with volumes |
| DEPL-03 | Update `Dockerfile` — add SQLite system library, remove any PostgreSQL client tooling | `libsqlite3-dev` (build stage) + `libsqlite3-0` (runtime stage) confirmed for Debian bookworm |
| DEPL-04 | Move database migration execution from `release_command` to `Application.start/2` via a `Release.migrate()` call | Pattern confirmed by Fly.io official docs; `MegaPlanner.Release.migrate/0` already exists |
| DEPL-05 | Upload the verified SQLite `.db` file to the Fly volume via `fly sftp` before deploying | `fly sftp put` works once a machine is running; requires a temporary machine if first deploy |
| DEPL-06 | Deploy to Fly.io and confirm app starts, migrations do not re-run, and volume-mounted database is used | `fly deploy` + `fly ssh console` verification pattern documented |
| VRFY-01 | Smoke test all major features against SQLite-backed production deployment | Manual HTTP testing against production endpoints |
| VRFY-02 | Confirm SQLite file persists across Fly.io app restarts (volume correctly mounted) | Volume persistence across stop/restart confirmed; second `fly deploy` is the test |
| VRFY-03 | Keep PostgreSQL running for 48 hours as rollback option, then decommission | `fly postgres detach` + `fly apps destroy mega-planner-api-db` is the sequence |
</phase_requirements>

---

## Summary

Phase 5 deploys the SQLite-backed Elixir app to the existing Fly.io machine (`mega-planner-api`, region `iad`). The current machine is in a `failed` state because it cannot connect to PostgreSQL (the `DATABASE_URL` secret points to Postgres but the app code now expects `DATABASE_PATH`). The core work is: create a Fly volume, update `fly.toml` and `Dockerfile`, move migrations into `Application.start/2`, upload the verified SQLite file, set the `DATABASE_PATH` secret, and deploy.

The machine is configured with `auto_stop_machines = "stop"`, which is safe for a single-machine SQLite deployment — the volume persists across stop/start cycles. The existing `MegaPlanner.Release.migrate/0` module is already written and correct; it only needs to be called from `Application.start/2` instead of the `release_command` shell script.

The PostgreSQL cluster (`mega-planner-api-db`) is unmanaged Fly Postgres and can be decommissioned with `fly postgres detach` + `fly apps destroy mega-planner-api-db` after the 48-hour rollback window.

**Primary recommendation:** Follow the exact sequence: volume create → fly.toml + Dockerfile update → Application.start/2 migration wiring → fly deploy (initial, for machine to exist) → fly sftp put (upload DB) → fly deploy (real deploy) → verify → keep Postgres 48h → decommission.

---

## Current Fly.io State

| Item | Current Value | Action Needed |
|------|--------------|---------------|
| App name | `mega-planner-api` | No change |
| Region | `iad` | Volume must be created in `iad` |
| Machine state | `failed` (launch failure) | Will be fixed by correct deploy |
| Machine ID | `7815697b2e6ee8` | — |
| Volumes attached | None (empty list) | Create `lifeboard_data` in `iad` |
| Secrets present | `DATABASE_URL` (Postgres), others | Add `DATABASE_PATH`, optionally unset `DATABASE_URL` |
| Postgres cluster | `mega-planner-api-db` (running) | Keep 48h post-cutover, then destroy |

---

## Standard Stack

### Core
| Tool/Config | Version | Purpose | Notes |
|-------------|---------|---------|-------|
| Fly CLI (`flyctl`) | v0.4.19 (installed) | Volumes, deploy, sftp, secrets | Current install confirmed |
| `ecto_sqlite3` | ~0.22 (already in mix.exs) | SQLite adapter | Already done in Phase 1 |
| Debian bookworm | `bookworm-20231009-slim` | Base image (already in Dockerfile) | — |
| `libsqlite3-dev` | system package | Build stage: compile exqlite NIF | Must be added to builder stage |
| `libsqlite3-0` | system package | Runtime stage: load SQLite shared lib | Must be added to runner stage |

### Fly.io Configuration
| Item | Value | Source |
|------|-------|--------|
| Volume create command | `fly volumes create lifeboard_data --size 1 --region iad --app mega-planner-api` | fly volumes create --help |
| `fly.toml` mounts section | `source = "lifeboard_data"`, `destination = "/data"` | Official Fly.io docs |
| DATABASE_PATH value | `/data/lifeboard.db` | Volume at `/data`, file directly inside |
| SFTP upload command | `fly sftp put <local-path> /data/lifeboard.db --app mega-planner-api` | fly sftp put --help |

---

## Architecture Patterns

### Recommended Sequence

The upload-before-deploy problem has a chicken-and-egg challenge: `fly sftp put` requires a running machine. The recommended sequence is:

1. Create volume
2. Update `fly.toml` + `Dockerfile` + `Application.start/2`
3. `fly deploy` — this creates a machine with the volume attached; the app may fail to start if `DATABASE_PATH` is not yet set, but that is OK — the machine runs long enough for SFTP
4. `fly secrets set DATABASE_PATH=/data/lifeboard.db` (also unset `DATABASE_URL`)
5. `fly sftp put server/mega_planner_dev.db /data/lifeboard.db` — uploads the verified 933KB SQLite file
6. `fly deploy` again — now the app starts cleanly with the pre-populated DB
7. Verify with `fly ssh console -C "ls -la /data/"`

**Alternative if machine is not running:** `fly machine run` with the volume attached via `--volume lifeboard_data:/data` using the `debian:bookworm-slim` image, SFTP the file, destroy the temp machine. This is more complex and should be avoided if possible.

### fly.toml Changes

**Remove:**
```toml
[deploy]
  release_command = '/app/bin/migrate'
```

**Add:**
```toml
[mounts]
  source = "lifeboard_data"
  destination = "/data"
```

**Add to `[env]`** (or set as secret — either works since it's not sensitive):
```toml
DATABASE_PATH = "/data/lifeboard.db"
```

**Result — full fly.toml `[env]` section:**
```toml
[env]
  PHX_HOST = 'mega-planner-api.fly.dev'
  PORT = '4000'
  DATABASE_PATH = '/data/lifeboard.db'
```

### Dockerfile Changes

**Builder stage** (add `libsqlite3-dev`):
```dockerfile
# Before (line 17):
RUN apt-get update -y && apt-get install -y build-essential git \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# After:
RUN apt-get update -y && apt-get install -y build-essential git libsqlite3-dev \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
```

**Runner stage** (add `libsqlite3-0`):
```dockerfile
# Before (line 59):
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# After:
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates libsqlite3-0 \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
```

**Note:** The Dockerfile currently does NOT install sqlite3 dev libs at all — `ecto_sqlite3` bundles its own `exqlite` NIF but needs the system library headers at build time and the shared library at runtime. Without `libsqlite3-0` in the runner stage, the NIF will fail to load with a "cannot load shared library" error.

### Pattern: Migration in Application.start/2

**Source:** Fly.io official SQLite3 guide; endorsed by Chris McCord

```elixir
# lib/mega_planner/application.ex
@impl true
def start(_type, _args) do
  MegaPlanner.Release.migrate()   # ADD THIS LINE

  children = [
    MegaPlannerWeb.Telemetry,
    MegaPlanner.Repo,
    {Phoenix.PubSub, name: MegaPlanner.PubSub},
    {Finch, name: MegaPlanner.Finch},
    MegaPlannerWeb.Endpoint
  ]

  opts = [strategy: :one_for_one, name: MegaPlanner.Supervisor]
  Supervisor.start_link(children, opts)
end
```

`MegaPlanner.Release.migrate/0` is already implemented correctly in `server/lib/mega_planner/release.ex`. It uses `Ecto.Migrator.with_repo/3` with `run(&1, :up, all: true)` which is idempotent — Ecto's `schema_migrations` table prevents re-running completed migrations.

**Why idempotent:** `Ecto.Migrator.run/3` with `all: true` checks the `schema_migrations` table and only runs migrations whose version numbers are not already present. Every subsequent deploy will call `migrate()` and it will do nothing (0 migrations applied).

### Pattern: Volume Path

The volume name (`lifeboard_data`) does NOT appear in the filesystem path. The path is purely derived from the `destination` in `fly.toml`. With `destination = "/data"`:

```
DATABASE_PATH = "/data/lifeboard.db"   # CORRECT
DATABASE_PATH = "/data/lifeboard_data/lifeboard.db"  # WRONG
```

The volume root will contain `lost+found` (Linux ext4 artifact). SQLite does not care about `lost+found` existing alongside the `.db` file.

### Pattern: Secrets Management

```bash
# Add DATABASE_PATH secret
fly secrets set DATABASE_PATH=/data/lifeboard.db --app mega-planner-api

# Remove DATABASE_URL (Postgres no longer used in prod)
fly secrets unset DATABASE_URL --app mega-planner-api

# Both can be done together:
fly secrets set DATABASE_PATH=/data/lifeboard.db \
  && fly secrets unset DATABASE_URL --app mega-planner-api
```

**Note:** `DATABASE_URL` is currently set as a secret pointing to the PostgreSQL cluster. The `runtime.exs` code reads `DATABASE_PATH`, so `DATABASE_URL` is no longer referenced by the app. Unsetting it is clean-up — it does not need to happen before deploy, but should be done to avoid confusion.

### Pattern: PostgreSQL Decommission Sequence

After the 48-hour rollback window:

```bash
# Step 1: Detach PostgreSQL from the app
fly postgres detach mega-planner-api-db --app mega-planner-api

# Step 2: Destroy the Postgres cluster (irreversible)
fly apps destroy mega-planner-api-db

# Note: DATABASE_URL secret is already unset, so detach is clean
```

The PostgreSQL cluster is an **unmanaged** Fly Postgres app (`mega-planner-api-db`). The correct destruction command is `fly apps destroy`, not `fly mpg destroy` (which is for managed Postgres).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Migration idempotency | Custom version checking | `Ecto.Migrator` with `schema_migrations` table | Already built into Ecto; re-running `run(:up, all: true)` is a no-op for applied migrations |
| File upload to volume | Custom HTTP upload or scp script | `fly sftp put` | CLI command built for this; handles WireGuard VPN automatically |
| SQLite NIF compilation | Bundling pre-compiled NIF | `libsqlite3-dev` apt package in builder | `exqlite` compiles the NIF against system headers during `mix deps.compile` |

---

## Common Pitfalls

### Pitfall 1: DATABASE_PATH Not Set Before First Deploy
**What goes wrong:** The first `fly deploy` will fail to start the app if `DATABASE_PATH` is not set, because `runtime.exs` raises `"environment variable DATABASE_PATH is missing"`. The machine will enter a crash loop.
**Why it happens:** Fly secrets need to be set before the app boots.
**How to avoid:** Set `DATABASE_PATH` secret before or immediately after the first deploy. The machine failing to start is acceptable for the "upload DB" step — the volume is still attached to the failed machine.
**Warning signs:** `fly logs` shows "environment variable DATABASE_PATH is missing" — this is expected in the intermediate state.

### Pitfall 2: release_command Has No Volume Access
**What goes wrong:** The `/app/bin/migrate` `release_command` currently in `fly.toml` runs in a separate VM snapshot before the volume is mounted. If this is not removed, migrations attempt to run against no database file.
**Why it happens:** Fly.io's `release_command` runs in an isolated VM that does not have the persistent volume attached — only the app VMs have volumes.
**How to avoid:** Remove `[deploy]` section from `fly.toml` entirely; move `MegaPlanner.Release.migrate()` to `Application.start/2`.
**Warning signs:** Release command succeeds (it gets no database error) but then the app starts with the wrong database, or the release command fails with file not found.

### Pitfall 3: libsqlite3 Missing from Runner Image
**What goes wrong:** The compiled `exqlite` NIF cannot load the shared library at runtime. The app crashes immediately with an error like `(ErlangError) Erlang error: {:load_failed, "Failed to load NIF library ..."}`.
**Why it happens:** The Dockerfile runner stage uses `debian:bookworm-slim` which does not include `libsqlite3-0`. The `exqlite` NIF is compiled against this library during build, but it must also be present at runtime.
**How to avoid:** Add `libsqlite3-0` to the runner stage `apt-get install` list.
**Warning signs:** App crashes immediately with NIF load error in `fly logs`.

### Pitfall 4: Uploading DB Before Machine Exists
**What goes wrong:** `fly sftp put` fails with "no instances found" if no machine is running.
**Why it happens:** SFTP requires an active SSH connection to a running machine.
**How to avoid:** Deploy first (even if app crashes due to missing `DATABASE_PATH`), then SFTP, then deploy again. The volume persists across the two deploys.
**Warning signs:** `fly sftp put` errors with "no instances" or connection refused.

### Pitfall 5: Scaling to Multiple Machines
**What goes wrong:** If the app is scaled to 2+ machines, new machines get empty volumes. Data appears to vanish.
**Why it happens:** Each Fly volume is 1:1 with a machine. A new machine gets a new, empty volume.
**How to avoid:** Keep `min_machines_running = 0` and only 1 machine. Never `fly scale count 2` for this app.
**Warning signs:** Auth works, but all user data is missing — you're hitting the second machine.

### Pitfall 6: Migration Boot Loop on Bad Migration
**What goes wrong:** A bad migration causes `MegaPlanner.Release.migrate()` to raise in `Application.start/2`, preventing the supervisor from starting, causing Fly to restart the machine in an infinite loop.
**Why it happens:** Calling `migrate()` before the supervisor starts means a migration error kills the whole boot sequence.
**How to avoid:** All migrations have been verified via `mix ecto.migrate` in Phase 2. The production SQLite file has already had all migrations applied (it was created by the Phase 4 import which runs `mix ecto.migrate` beforehand). The `migrate()` call should produce 0 migrations on the first production deploy.
**Warning signs:** `fly logs` shows repeated migration errors followed by crash/restart cycles.

### Pitfall 7: Wrong DATABASE_PATH Including Volume Name
**What goes wrong:** If `DATABASE_PATH = /data/lifeboard_data/lifeboard.db` is used, Ecto tries to open a file at a non-existent path (there is no `lifeboard_data` subdirectory inside `/data` — the volume name is not a path component).
**Why it happens:** Confusion between the volume `source` name and the mount path.
**How to avoid:** Use `DATABASE_PATH = /data/lifeboard.db`. The volume is mounted at `/data`; the file goes directly inside.

---

## Code Examples

### Application.start/2 with Migration Call
```elixir
# Source: https://fly.io/docs/elixir/advanced-guides/sqlite3/
# File: server/lib/mega_planner/application.ex

@impl true
def start(_type, _args) do
  MegaPlanner.Release.migrate()

  children = [
    MegaPlannerWeb.Telemetry,
    MegaPlanner.Repo,
    {Phoenix.PubSub, name: MegaPlanner.PubSub},
    {Finch, name: MegaPlanner.Finch},
    MegaPlannerWeb.Endpoint
  ]

  opts = [strategy: :one_for_one, name: MegaPlanner.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### fly.toml After Changes
```toml
# fly.toml app configuration file for mega-planner-api

app = 'mega-planner-api'
primary_region = 'iad'

[build]

# REMOVED: [deploy] release_command

[mounts]
  source = "lifeboard_data"
  destination = "/data"

[env]
  PHX_HOST = 'mega-planner-api.fly.dev'
  PORT = '4000'
  DATABASE_PATH = '/data/lifeboard.db'

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = 'stop'
  auto_start_machines = true
  min_machines_running = 0
  processes = ['app']

  [http_service.concurrency]
    type = 'connections'
    hard_limit = 1000
    soft_limit = 1000

  [[http_service.checks]]
    interval = '10s'
    timeout = '2s'
    grace_period = '5s'
    method = 'GET'
    path = '/api/health'

[[vm]]
  memory = '1gb'
  cpu_kind = 'shared'
  cpus = 1
```

### Dockerfile Builder Stage (SQLite addition)
```dockerfile
# Build stage — add libsqlite3-dev
RUN apt-get update -y && apt-get install -y build-essential git libsqlite3-dev \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
```

### Dockerfile Runner Stage (SQLite addition)
```dockerfile
# Runner stage — add libsqlite3-0
RUN apt-get update -y && \
  apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates libsqlite3-0 \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*
```

### Full Deploy + Verify Command Sequence
```bash
# 1. Create volume
fly volumes create lifeboard_data --size 1 --region iad --app mega-planner-api

# 2. Set DATABASE_PATH secret, remove DATABASE_URL
fly secrets set DATABASE_PATH=/data/lifeboard.db --app mega-planner-api
fly secrets unset DATABASE_URL --app mega-planner-api

# 3. First deploy (fly.toml + Dockerfile updated, app may crash without DB file — OK)
cd server && fly deploy

# 4. Upload the verified SQLite file
fly sftp put server/mega_planner_dev.db /data/lifeboard.db --app mega-planner-api

# 5. Second deploy (now with DB file present — app starts cleanly)
fly deploy

# 6. Verify volume and file
fly ssh console -C "ls -la /data/" --app mega-planner-api

# 7. Confirm migrations did not re-run (check logs)
fly logs --app mega-planner-api

# 8. Smoke test (hit production URL for all major features)
# Manual: auth, tasks, budget, inventory, goals, habits

# 9. No-op redeploy to verify persistence
fly deploy
fly ssh console -C "ls -la /data/" --app mega-planner-api

# --- 48 hours later ---

# 10. Decommission PostgreSQL
fly postgres detach mega-planner-api-db --app mega-planner-api
fly apps destroy mega-planner-api-db
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|-----------------|-------|
| `release_command` for migrations | `Application.start/2` migration | Fly volumes not accessible during `release_command`; startup migration is idempotent |
| `DATABASE_URL` pointing to PostgreSQL | `DATABASE_PATH` pointing to `/data/lifeboard.db` | Already implemented in `runtime.exs` (Phase 1) |
| No SQLite libs in Dockerfile | `libsqlite3-dev` (build) + `libsqlite3-0` (runtime) | Required for `exqlite` NIF compilation and loading |

**Known deprecated:**
- `release_command` in fly.toml when using volumes — must be removed (DEPL-02)
- `DATABASE_URL` secret — already unused by app code; should be unset after cutover

---

## Open Questions

1. **Does `fly sftp put` work with the machine in `failed` state?**
   - What we know: `fly sftp put` requires a running machine. The current machine is in `failed` state.
   - What's unclear: Whether the first `fly deploy` (after changes) will start the machine successfully enough for SFTP to work, even if the app crashes internally.
   - Recommendation: Set `DATABASE_PATH` secret before the first deploy attempt so the app has a chance to start. If SFTP still fails, use `fly machine run --shell --volume lifeboard_data:/data debian:bookworm-slim` to mount the volume in a temp machine and copy the file.

2. **Will `chmod` be needed on the uploaded SQLite file?**
   - What we know: `fly sftp put` defaults to mode `0644`. The app runs as `nobody`.
   - What's unclear: Whether `nobody` can read/write a `0644` file uploaded by `root`.
   - Recommendation: If the app reports SQLite read-only errors, run `fly ssh console -C "chmod 666 /data/lifeboard.db"` or use `fly sftp put --mode 0666`.

3. **Does the first deploy's `migrate()` call correctly find 0 pending migrations?**
   - What we know: The local SQLite file was created by `mix ecto.migrate` in Phase 4; all migrations are recorded in `schema_migrations`. The production import used the fully-migrated schema.
   - What's unclear: Whether `schema_migrations` was included in the Phase 4 import (it is an Ecto-managed table, not a user data table, so it may NOT have been exported).
   - Recommendation: Check whether `schema_migrations` is in the Phase 4 export. If not, `migrate()` will attempt to run all migrations against the already-correct schema. Since all Phase 2 migrations are idempotent with respect to schema state (creates are `CREATE TABLE IF NOT EXISTS` or equivalent), this may succeed. But if it fails, the fix is to pre-populate `schema_migrations` before deploy by running `mix ecto.migrate` against the dev DB (which should already be done).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in Elixir) |
| Config file | `server/test/test_helper.exs` |
| Quick run command | `cd server && mix test --no-start` |
| Full suite command | `cd server && mix test` |

### Phase Requirements → Test Map

This phase is primarily operational (deploy, verify, cutover). Most requirements are verified by running CLI commands and manual smoke testing rather than ExUnit tests.

| Req ID | Behavior | Test Type | Command | Notes |
|--------|----------|-----------|---------|-------|
| DEPL-01 | Volume exists in correct region | smoke | `fly volumes list --app mega-planner-api` | Verify `lifeboard_data` listed with `iad` region |
| DEPL-02 | fly.toml has mounts, no release_command | static | `grep -v release_command server/fly.toml && grep -A2 '\[mounts\]' server/fly.toml` | File inspection |
| DEPL-03 | Dockerfile has sqlite libs | static | `grep libsqlite server/Dockerfile` | File inspection |
| DEPL-04 | Application.start/2 calls migrate | static | `grep -A3 'def start' server/lib/mega_planner/application.ex` | File inspection |
| DEPL-05 | SQLite file on volume after upload | smoke | `fly ssh console -C "ls -la /data/" --app mega-planner-api` | Shows `lifeboard.db` |
| DEPL-06 | App starts and uses volume DB | smoke | `fly logs --app mega-planner-api` | No crash; migrate 0 applied |
| VRFY-01 | Features work in production | manual-only | Browser/curl testing against production URL | Auth, tasks, budget, inventory, goals, habits |
| VRFY-02 | Data persists across restart | smoke | Second `fly deploy` + `fly ssh console -C "ls -la /data/"` | File present, same size |
| VRFY-03 | Postgres decommissioned | smoke | `fly machine list --app mega-planner-api-db 2>&1 \| grep "No machines"` | After 48h window |

### Sampling Rate
- **Per task commit:** Static file checks (grep commands above)
- **Per wave merge:** `fly logs` inspection + smoke test
- **Phase gate:** All smoke tests green before marking phase complete

### Wave 0 Gaps

None for ExUnit. All verifications are operational (CLI + manual) rather than automated test files.

---

## Sources

### Primary (HIGH confidence)
- [fly.io/docs/elixir/advanced-guides/sqlite3/](https://fly.io/docs/elixir/advanced-guides/sqlite3/) — Official Fly.io Elixir SQLite guide: Application.start/2 migration pattern, release_command removal, volume mount syntax
- [fly.io/docs/reference/configuration/](https://fly.io/docs/reference/configuration/) — fly.toml [mounts] section syntax, [deploy] section
- `fly volumes create --help` (CLI v0.4.19) — confirmed flags: `--size`, `--region`, `--app`
- `fly sftp put --help` (CLI v0.4.19) — confirmed: local-path remote-path syntax, `--mode` flag
- `fly machine run --help` (CLI v0.4.19) — confirmed: `--volume` flag for temporary machine approach
- `fly postgres detach --help` (CLI v0.4.19) — confirmed detach syntax
- `fly apps destroy --help` (CLI v0.4.19) — confirmed destruction syntax
- `fly status` / `fly machine list` — confirmed current machine state: `failed`, region `iad`, no volumes
- `fly secrets list` — confirmed `DATABASE_URL` currently set (Postgres), `DATABASE_PATH` not yet set

### Secondary (MEDIUM confidence)
- [gist.github.com/mcrumm/98059439c673be7e0484589162a54a01](https://gist.github.com/mcrumm/98059439c673be7e0484589162a54a01) — Phoenix + SQLite deployment tips by maintainer; confirmed Application.start/2 pattern, DATABASE_PATH path format
- [community.fly.io — upload SQLite DB before deploy](https://community.fly.io/t/how-to-upload-an-initial-sqlite-db-to-a-volume-before-deploy/10768) — confirmed chicken-and-egg problem; deploy first then SFTP
- [packages.debian.org/bookworm/libsqlite3-dev](https://packages.debian.org/bookworm/libsqlite3-dev) — confirmed package exists in bookworm
- [packages.debian.org/bookworm/libsqlite3-0](https://packages.debian.org/bookworm/libsqlite3-0) — confirmed runtime library package in bookworm

### Tertiary (LOW confidence)
- WebSearch community results on volume path format — cross-verified with official docs confirming volume name NOT in path

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Fly CLI explored live; current app state confirmed via `fly status`, `fly machine list`, `fly secrets list`, `fly volumes list`
- Architecture: HIGH — Official Fly.io docs confirmed; `fly.toml` and `Dockerfile` read directly; `Application.start/2` and `MegaPlanner.Release.migrate/0` confirmed in codebase
- Pitfalls: HIGH — Most pitfalls confirmed from official docs + live app state (machine in `failed` state confirms `DATABASE_URL` problem)

**Research date:** 2026-03-08
**Valid until:** 2026-04-08 (Fly.io CLI changes frequently; re-verify CLI flags if > 30 days)
