---
phase: 05-fly-io-deployment-cutover
plan: 01
subsystem: infra
tags: [fly.io, docker, sqlite, ecto_sqlite3, exqlite, deployment]

# Dependency graph
requires:
  - phase: 04-data-migration-pipeline
    provides: Fully migrated SQLite database ready for production use

provides:
  - Dockerfile with libsqlite3-dev (builder) and libsqlite3-0 (runner) for exqlite NIF
  - fly.toml with lifeboard_data volume mount at /data and DATABASE_PATH env var
  - Application.start/2 calling MegaPlanner.Release.migrate() before supervisor start

affects:
  - 05-02 (volume creation and initial deploy relies on these file configs)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Migrations run in Application.start/2 (not release_command) so volume is accessible"
    - "libsqlite3-dev in builder stage + libsqlite3-0 in runner stage for NIF compile+load"

key-files:
  created: []
  modified:
    - server/Dockerfile
    - server/fly.toml
    - server/lib/mega_planner/application.ex

key-decisions:
  - "release_command removed from fly.toml: release VMs do not have volumes attached, so migration must run in Application.start/2 instead"
  - "DATABASE_PATH set as plain [env] value (not secret) since /data/lifeboard.db is not sensitive"
  - "libsqlite3-0 (runtime) separate from libsqlite3-dev (build-time headers) — both required for exqlite NIF lifecycle"

patterns-established:
  - "migrate() call pattern: MegaPlanner.Release.migrate() first line of start/2, unconditional, idempotent"

requirements-completed: [DEPL-02, DEPL-03, DEPL-04]

# Metrics
duration: 1min
completed: 2026-03-08
---

# Phase 05 Plan 01: Dockerfile, fly.toml, and Application Boot — Codebase Preparation Summary

**SQLite NIF libraries added to Dockerfile builder and runner stages, fly.toml updated with lifeboard_data volume mount and DATABASE_PATH, and Application.start/2 wired to call idempotent migrations before supervisor start**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-08T07:07:33Z
- **Completed:** 2026-03-08T07:08:33Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Added `libsqlite3-dev` to Dockerfile builder stage so exqlite NIF compiles during `docker build`
- Added `libsqlite3-0` to Dockerfile runner stage so exqlite NIF loads successfully at container startup
- Removed `[deploy] release_command` from fly.toml (release VM has no volume access); added `[mounts]` binding `lifeboard_data` to `/data` and `DATABASE_PATH = '/data/lifeboard.db'` to `[env]`
- Wired `MegaPlanner.Release.migrate()` as the first call in `Application.start/2` — runs before supervisor, idempotent via schema_migrations table

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SQLite system libraries to Dockerfile** - `3048c35` (feat)
2. **Task 2: Update fly.toml — remove release_command, add volume mount and DATABASE_PATH** - `7e4cd1e` (feat)
3. **Task 3: Wire MegaPlanner.Release.migrate() into Application.start/2** - `9ee546d` (feat)

## Files Created/Modified
- `server/Dockerfile` - Added libsqlite3-dev to builder apt-get install; added libsqlite3-0 to runner apt-get install
- `server/fly.toml` - Removed [deploy] release_command section; added [mounts] for lifeboard_data volume; added DATABASE_PATH to [env]
- `server/lib/mega_planner/application.ex` - Added MegaPlanner.Release.migrate() call before children definition in start/2

## Decisions Made
- `release_command` removed entirely: Fly.io release VMs run in isolated containers without persistent volumes attached, so any migration call there would fail against an empty/missing database file. Moving migrate() to Application.start/2 ensures it runs in the actual app process that has /data mounted.
- `DATABASE_PATH` as plain `[env]` (not `fly secrets`): The path `/data/lifeboard.db` is not sensitive information — it is a filesystem path determined by the volume mount. Secrets are for credentials and API keys only.
- Both libsqlite libraries are required: `libsqlite3-dev` provides C headers for NIF compilation at build time; `libsqlite3-0` provides the shared library for dynamic loading at runtime. Missing either causes a different failure mode.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required for this plan. The `lifeboard_data` volume will be created in Plan 02.

## Next Phase Readiness
- All three code changes committed and verified
- Codebase is ready for Fly.io operations in Plan 02 (volume creation, secrets, and deploy)
- Verification commands all pass: grep libsqlite Dockerfile (2 lines), grep -c release_command fly.toml (0), grep -A3 "def start" application.ex (migrate() first)

---
*Phase: 05-fly-io-deployment-cutover*
*Completed: 2026-03-08*

## Self-Check: PASSED

- server/Dockerfile: FOUND
- server/fly.toml: FOUND
- server/lib/mega_planner/application.ex: FOUND
- .planning/phases/05-fly-io-deployment-cutover/05-01-SUMMARY.md: FOUND
- Commit 3048c35 (Task 1): FOUND
- Commit 7e4cd1e (Task 2): FOUND
- Commit 9ee546d (Task 3): FOUND
