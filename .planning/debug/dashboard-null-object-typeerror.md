---
status: awaiting_human_verify
trigger: "Investigate issue: dashboard-null-object-typeerror"
created: 2026-03-16T00:00:00-04:00
updated: 2026-03-16T19:52:00-04:00
---

## Current Focus

hypothesis: Persisted dashboard widget definitions were corrupted during SQLite migration, producing unsupported widget types that the dashboard render path does not guard against.
test: Hand off the patched worktree for push/deploy and confirm the dashboard and trip-receipts flows against production.
expecting: Production preferences will be normalized on read/migration, the dashboard will stop calling `markRaw(undefined)`, and storeless trip receipts will render successfully.
next_action: Push/deploy the current source changes from an operator shell with git/Fly access, then verify the real production dashboard and trip-receipts page.

## Symptoms

expected: Dashboard renders cards for habits, tasks, goals, etc. without console errors.
actual: Repeated TypeError: Cannot convert undefined or null to object, with stack frames pointing into DashboardView and card render paths.
errors: Browser console shows TypeError at runtime in production.
reproduction: Open dashboard for a real user with existing data.
started: Reported after SQLite migration and backend redeploys; may be due to null/shape differences in API data now coming from SQLite-backed responses.

## Eliminated

## Evidence

- timestamp: 2026-03-16T00:12:00-04:00
  checked: Dashboard view, preferences store, widget registry, and widget config
  found: The dashboard renders widgets dynamically from `preferences.dashboard_widgets` via `widgetComponents[widget.type]` with no guard for unsupported types.
  implication: Any corrupted or legacy widget type in persisted preferences can break the render path.

- timestamp: 2026-03-16T00:18:00-04:00
  checked: Local `user_preferences.dashboard_widgets` rows in SQLite
  found: Multiple rows contain widget `type` values like `696e7665-6e74-6f72-795f-737461747573` instead of `inventory_status`.
  implication: The SQLite migration/import produced malformed persisted dashboard widget data, consistent with a production-only crash for real users with saved dashboard layouts.

- timestamp: 2026-03-16T00:35:00-04:00
  checked: Local SQLite repair SQL against `user_preferences.dashboard_widgets`
  found: Three rows contained the corrupted inventory widget token before repair; zero rows contained it after applying the replacement SQL.
  implication: The migration repair logic fixes the persisted data shape that was breaking the dashboard.

- timestamp: 2026-03-16T19:48:00-04:00
  checked: Worktree-level mechanical validation
  found: `git diff --check` is clean for the relevant source files after removing trailing whitespace.
  implication: The edited files are mechanically clean even though full build/test/deploy execution is blocked in this shell.

- timestamp: 2026-03-16T19:50:00-04:00
  checked: Operator actions from this shell
  found: Git cannot create `.git/index.lock`, `flyctl` requires unavailable auth when pointed at a writable config dir, and local `npm` install/build tooling is unstable in this environment.
  implication: Code changes are ready, but push/deploy and full build verification require a normal operator shell or user confirmation after shipping.

## Resolution

root_cause: The PostgreSQL export task treated any 16-byte binary as a UUID before checking whether it was a valid string. The widget type `inventory_status` is exactly 16 bytes, so saved dashboard widget JSON was exported as the bogus UUID-like string `696e7665-6e74-6f72-795f-737461747573`. The frontend then indexed `widgetComponents` with that unsupported type and called `markRaw(undefined)`, which triggers the repeated `Cannot convert undefined or null to object` runtime error.
fix:
fix: Added server-side normalization and a repair migration for corrupted dashboard widget types, hardened the frontend dashboard widget normalization/render path against unsupported types, corrected the PostgreSQL export task so valid 16-character strings are no longer serialized as UUIDs, and kept the trip-receipts store-name fallback fix plus a focused regression test.
verification: Confirmed the corrupted dashboard widget token existed in three local SQLite preference rows and that the repair SQL removed it; `git diff --check` passes for the relevant source files. Full frontend build, backend test execution, git push, and Fly deploy could not be completed from this shell because npm/mix/operator access is restricted here.
files_changed:
  - server/lib/mega_planner/accounts.ex
  - server/lib/mix/tasks/migrate.export.ex
  - server/lib/mega_planner/accounts/user_preferences.ex
  - server/priv/repo/migrations/20260316233000_fix_corrupted_dashboard_widget_types.exs
  - client/src/stores/preferences.ts
  - client/src/views/DashboardView.vue
  - server/lib/mega_planner/inventory.ex
  - server/test/mega_planner/sqlite_regressions_test.exs
