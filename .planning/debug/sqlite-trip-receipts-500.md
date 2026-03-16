---
status: investigating
trigger: "Investigate issue: sqlite-trip-receipts-500"
created: 2026-03-16T23:24:24Z
updated: 2026-03-17T00:35:10Z
---

## Current Focus

hypothesis: Root cause is fixed; current focus is final verification and deployment because the local route sweep now shows the affected inventory/receipt endpoints all handle the nil-`store_id` stop shape correctly.
test: Record the route-level verification (`trip_receipts`, purchases sheet show, trip show, stop index, store inventory) and then deploy the patch so production can be checked with the real dataset.
expecting: Local status codes remain `200` for the affected inventory/receipt surface, and production health remains green after deploy.
next_action: Persist the local route-sweep evidence and push the patch through deployment.

## Symptoms

expected: /api/inventory/trip-receipts should return receipt-backed inventory purchase groups or an empty list.
actual: Browser console shows GET https://mega-planner-api.fly.dev/api/inventory/trip-receipts?... returning 500 and frontend logs 'Failed to fetch trip receipts'.
errors: Production request fails with 500 in the inventory sheet purchases view.
reproduction: Open the purchases/trip receipts section for an inventory sheet in production.
started: Reported after earlier SQLite fixes and redeploy; local generic sweep had passed, so this may be data-specific.

## Eliminated

## Evidence

- timestamp: 2026-03-16T23:26:10Z
  checked: inventory trip receipts route and context implementation
  found: `InventorySheetController.trip_receipts/2` delegates directly to `Inventory.list_trip_receipts/1`, which groups Purchases-sheet items and builds `store_name` with `(stop.store && stop.store.name) || stop.stop_name`.
  implication: Any receipt item whose stop has no loaded store association will hit a fallback that references a non-existent field on the `Stop` schema.

- timestamp: 2026-03-16T23:27:48Z
  checked: local SQLite data for Purchases sheet items and stops
  found: the current user household has a Purchases-sheet inventory item (`117d58ac-7c8e-47db-ad4e-14200e0fd2dc`) whose `stop_id` points to stop `4cd00202-4cf8-4a08-899d-651fd0f9c41c`, and that stop has `store_id = nil` with `store_name = "Manual Store Name"`.
  implication: The locally migrated data contains the same shape that would force the broken fallback path, so this is not purely a production-only schema issue.

- timestamp: 2026-03-17T00:29:52Z
  checked: patched `Inventory.list_trip_receipts/1` against the local migrated SQLite DB
  found: after recompiling `server/lib/mega_planner/inventory.ex` directly and starting only `MegaPlanner.Repo`, `MegaPlanner.Inventory.list_trip_receipts("83e73053-5393-4ef3-9773-6f1c17b2652f")` returned the affected receipt group with `store_name: "Manual Store Name"` instead of crashing.
  implication: The patched fallback handles the real migrated row shape and removes the failure for the affected household data.

- timestamp: 2026-03-17T00:30:15Z
  checked: direct access to `stop.stop_name` on the affected `MegaPlanner.Receipts.Stop` struct
  found: Elixir raises `key :stop_name not found` for the real stop row `4cd00202-4cf8-4a08-899d-651fd0f9c41c`.
  implication: The original `list_trip_receipts/1` implementation would raise at runtime on this migrated data, which explains the production 500 precisely.

- timestamp: 2026-03-17T00:30:28Z
  checked: adjacent stop/store fallback code in receipts, trip, stop, budget, calendar, and inventory contexts
  found: the remaining relevant code paths use `stop.store_name` or guard the association safely; no other live `stop.stop_name` accesses remain.
  implication: This bug generalizes to stop-backed inventory receipt grouping wherever that stale field were used, but in the current codebase the confirmed crashing instance is isolated to `Inventory.list_trip_receipts/1`.

- timestamp: 2026-03-17T00:35:03Z
  checked: local controller-level sweep against the migrated SQLite data
  found: `InventorySheetController.trip_receipts`, `InventorySheetController.show` for the Purchases sheet, `TripController.show`, `StopController.index`, and `StoreController.get_inventory` each returned `200` when invoked with the affected household data.
  implication: The fix removes the crashing path and adjacent inventory/receipt routes remain healthy for the same household after the SQLite migration.

## Resolution

root_cause: `Inventory.list_trip_receipts/1` still referenced `stop.stop_name`, a field that no longer exists on `MegaPlanner.Receipts.Stop`. Migrated SQLite data includes Purchases-sheet inventory items whose stops have `store_id = nil` and only `store_name`, so the fallback path executed and raised `key :stop_name not found`, producing a 500 for `/api/inventory/trip-receipts`.
fix: Changed the trip receipt serializer fallback to use `stop.store_name || (stop.store && stop.store.name)` so stops without a linked store still serialize safely.
verification: Patched function returns the affected real receipt row from the migrated SQLite DB; direct access to the old field reproduces the exact runtime failure; a controller-level local sweep returned `200` for `trip_receipts`, purchases-sheet show, trip show, stop index, and store inventory; adjacent receipt/inventory stop fallbacks were searched and no other live `stop.stop_name` accesses remain.
files_changed:
  - server/lib/mega_planner/inventory.ex
