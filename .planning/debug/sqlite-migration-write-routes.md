---
status: investigating
trigger: "Investigate issue: sqlite-migration-write-routes"
created: 2026-03-16T21:37:06Z
updated: 2026-03-16T21:49:38Z
---

## Current Focus

hypothesis: The primary shared root cause is SQLite constraint-name drift on custom unique indexes, and a secondary hardening gap is controllers that pattern-match on `{:ok, ...}` instead of handling changeset errors.
test: Patch every affected custom-named unique constraint to accept the SQLite-generated name and harden the template create controller; then rerun duplicate-write reproductions.
expecting: Duplicate/conflicting writes will return changeset errors instead of raising 500s, and template create will no longer crash on any insert failure.
next_action: Add a shared unique-constraint helper, update the affected schemas/controllers, and verify duplicate task/category/store-like flows.

## Symptoms

expected: Existing API routes continue to work after the Postgres to SQLite migration, including task creation and text template save flows.
actual: Routes such as /api/text-templates and /api/tasks return HTTP 500 during write flows.
errors: Browser shows "Failed to load resource: the server responded with a status of 500" and frontend logs show "Request failed" while saving templates and tasks.
reproduction: Try creating/saving a text template for task_title; try creating a task through the calendar flow or direct API write.
started: Regression started after migrating from PostgreSQL to SQLite.

## Eliminated

## Evidence

- timestamp: 2026-03-16T21:37:38Z
  checked: router and codebase search for failing endpoints
  found: /api/text-templates maps to TemplateController.create_text_template and /api/tasks maps to TaskController.create; both route into context functions that call Repo.insert/Repo.update.
  implication: The regression likely lives below routing and basic controller dispatch.

- timestamp: 2026-03-16T21:37:38Z
  checked: SQLite migration-related code search
  found: the backend now uses ecto_sqlite3 and contains many SQLite compatibility changes, but the failing template/task writes still use straightforward Repo.insert flows.
  implication: A shared adapter/schema/data assumption is more likely than one bad custom SQL query.

- timestamp: 2026-03-16T21:38:21Z
  checked: TemplateController, Templates, TextTemplate, TaskController, Calendar, and Task schema code
  found: the two failing examples use standard changesets and Repo inserts; task creation additionally validates referenced user/household IDs via Repo.get during changeset validation.
  implication: If both fail, the shared problem is likely in insert persistence or returned schema loading rather than in controller wiring.

- timestamp: 2026-03-16T21:40:33Z
  checked: direct SQLite reproductions using the compiled app and the real dev database
  found: inserting a `text_templates` row and creating a task with a real user/household both succeeded through the backend contexts.
  implication: The regression is not a blanket SQLite failure for all writes; it likely depends on the exact request payload or API execution path used by the browser flows.

- timestamp: 2026-03-16T21:46:11Z
  checked: full router-level reproductions for task and text-template writes, including duplicate submissions
  found: duplicate task creation raises `Ecto.ConstraintError` because SQLite reports `tasks_title_date_household_id_index` while the changeset only declares `tasks_title_date_household_unique`; duplicate text-template saves still succeed because that route uses `ON CONFLICT DO NOTHING`.
  implication: A shared post-migration failure mode is mismatched constraint names between SQLite and the existing changesets, which converts expected validation failures into HTTP 500s.

- timestamp: 2026-03-16T21:49:38Z
  checked: schema/controller scan for related patterns
  found: multiple write schemas use custom `unique_constraint name:` values, and `TemplateController.create_text_template/2` still uses `{:ok, _} = ...`, which would crash on any non-successful insert.
  implication: The fix should be systematic across custom-named constraints and should harden at least the text-template controller path against unhandled changeset errors.

## Resolution

root_cause: SQLite reports different constraint/index names than the Postgres-era names hardcoded in some changesets, so duplicate/conflicting writes raise `Ecto.ConstraintError` instead of returning changeset errors.
fix:
verification:
files_changed: []
