---
name: Common Problems
description: Catalog of recurring bugs, gotchas, and patterns that cause issues in Lifeboard. Check this skill FIRST when debugging any issue — the problem may already be documented with a known fix.
---

# Common Problems Skill

This skill catalogs known recurring issues in Lifeboard. When you encounter a bug or unexpected behavior, **check this list first** before deep-diving into investigation. Many bugs are variations of patterns documented here.

## How to Use

1. **When debugging**: Scan the categories below for matching symptoms
2. **When filing a bug**: Reference the relevant pattern in the "Common Problems to Check" section
3. **When fixing a bug**: If you discover a new pattern, **add it here** so future bugs are caught faster

---

## Category 1: BaseItemEntry Prop Mapping

### Problem: Inconsistent item display across views

**Symptoms**: The same purchase shows different text/values in different screens (Trip view vs Inventory vs Budget).

**Root Cause**: Different parent components pass different props to `BaseItemEntry`. The unified display uses `formatItemCell()` which composes: `Count Brand Item CountUnit of Quantity QuantityUnit`.

**Affected Components**:
- `TripReceiptList.vue` — uses `item.name`, `item.brand`, `item.count`, etc. from `InventoryItem` shape
- `PurchaseList.vue` — uses `purchase.item`, `purchase.brand`, `purchase.count`, etc. from `Purchase` shape
- `BudgetDayDetail.vue` — uses `purchase.item`, `purchase.brand`, etc. from expanded trip purchases
- `SheetView.vue` — uses inventory item data shape (different field names)

**Fix Pattern**: Ensure all callers of `BaseItemEntry` pass the same logical data through the same props. The **canonical prop set** is:
```
:name :brand :count :count-unit :units :unit-measurement 
:store :store-code :price :total :price-per-count :price-per-unit :taxable :tags
```

**Key Gotcha**: `TripReceiptList` uses `item.quantity` → `units` prop, while `PurchaseList` uses `purchase.units` → `units` prop. If the backend returns different field names for the same concept, the display diverges.

**Detailed Fix Skill**: See `.agent/skills/fix-item-display-consistency/SKILL.md` for the complete diagnosis and fix workflow, including the `getTotalUnits()` pattern and backend serializer checklist.

---

## Category 2: CSS Overflow / Scroll Issues

### Problem: Long lists not scrollable in modals

**Symptoms**: A modal or popout shows a list that extends beyond the viewport, but there's no scrollbar.

**Root Cause**: Missing `overflow-auto` or `overflow-y-auto` on the list container, OR the parent container has a fixed height that doesn't constrain the child.

**Fix Pattern**:
1. The modal's outer container needs `max-h-[Xvh]` and `flex flex-col`
2. The scrollable content area needs `flex-1 overflow-auto`
3. Header and footer need `shrink-0`

**Template**:
```html
<div class="max-h-[85vh] flex flex-col">
  <div class="shrink-0"><!-- Header --></div>
  <div class="flex-1 overflow-auto"><!-- Scrollable content --></div>
  <div class="shrink-0"><!-- Footer --></div>
</div>
```

**Known Occurrences**:
- `BudgetDayDetail.vue` — expanded trip purchase lists can overflow when many items exist

**Detailed Fix Skill**: See `.agent/skills/fix-modal-overflow/SKILL.md` for the complete flex chain pattern, min-h-0 gotcha, safety net technique, and modal checklist.

---

## Category 3: Vue Reactivity Failures

### Problem: UI doesn't update after data changes

**Symptoms**: Data is confirmed changed in store/API, but the component doesn't re-render.

**Common Causes**:
1. **Set/Map mutations** — `mySet.add(x)` doesn't trigger reactivity. Must reassign: `mySet = new Set(mySet)`
2. **Object property addition** — Adding new keys to reactive objects. Use `reactive()` or `ref()` properly.
3. **Computed dependency missed** — computed property doesn't reference the reactive source correctly.
4. **Store action doesn't update state** — The Pinia action completes but doesn't mutate the store state that the component watches.

**Fix Pattern**: See workflow `/vue-reactivity-testing` for systematic debugging.

---

## Category 4: Teleport / Modal Z-Index Conflicts

### Problem: Modal appears behind another element, or clicking outside doesn't close

**Symptoms**: A modal or popout renders but is visually behind another overlay, or click-outside handler fires immediately.

**Common Causes**:
1. **Z-index stacking** — Multiple `<Teleport to="body">` elements competing. 
2. **Click propagation** — The event that opens the modal also triggers the outside-click handler that closes it.

**Fix Pattern**: See workflow `/click-collision-hazard` for the standard prevention approach.

---

## Category 5: Data Shape Mismatches (Backend vs Frontend)

### Problem: Frontend expects field X but backend returns field Y

**Symptoms**: Data renders as `undefined`, `null`, or `NaN` in the UI.

**Common Causes**:
1. **Serializer differences** — The Elixir JSON serializer may use `snake_case` while the TypeScript type expects `camelCase` (though Lifeboard standardizes on `snake_case` in API responses).
2. **Nested vs flat** — Purchase data from a trip stop has nested structure (`stop.purchases[]`), but direct purchase lists are flat.
3. **Computed fields missing** — Fields like `total_price`, `price_per_count` may not be included in all serializer views.

**Fix Pattern**: Check the backend serializer/view module. In Elixir, look at `*_json.ex` view files to confirm what fields are emitted for each endpoint.

---

## Category 6: Budget ↔ Purchase Cascade Issues

### Problem: Deleting/creating a purchase doesn't update the budget, or vice versa

**Symptoms**: Budget calendar still shows an entry for a deleted purchase, or a new purchase doesn't appear in the budget.

**Common Causes**:
1. **Missing cascade delete** — Budget entry not deleted when purchase is deleted
2. **Missing back-link** — Purchase created without `budget_entry_id`, or budget entry created without `purchase_id` back-link
3. **Stale frontend cache** — Budget store not refreshed after purchase mutation

**Fix Pattern**: After any purchase CRUD, ensure:
- Budget store is refreshed (`budgetStore.fetchEntries()`)
- Backend cascade deletes are confirmed (check `on_delete` in Ecto schema)

---

## Adding New Patterns

When you discover a new recurring problem:

1. **Add it here** under the appropriate category (or create a new one)
2. **Include**: Symptoms, Root Cause, Fix Pattern, and Known Occurrences
3. **Reference this skill** in the bug report's "Common Problems to Check" section
4. **Update the bug-noting skill** cross-reference table if a new category warrants a mapping
