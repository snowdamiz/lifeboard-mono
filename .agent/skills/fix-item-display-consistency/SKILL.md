---
name: Fix Item Display Consistency
description: How to diagnose and fix inconsistent item/purchase display across different views in Lifeboard. Covers the InventoryItem vs Purchase data shape mismatch, BaseItemEntry prop alignment, and backend serializer completeness.
---

# Fix Item Display Consistency

This skill documents how to solve the recurring problem where the same purchase/item looks different across views.

## Problem Pattern

The same conceptual item (e.g., "2 boxes of Cheerios, 12 oz each") may display differently in:
1. **Trip Manager** (Calendar → Trip → PurchaseList)
2. **Inventory Purchases** (Inventory → Purchases sheet → TripReceiptList)
3. **Budget Day Detail** (Budget → click day total → expanded trip)

### Root Cause: Two Data Shapes for the Same Thing

| Data Shape | Used By | `quantity`/`units` meaning |
|-----------|---------|---------------------------|
| **Purchase** | PurchaseList, BudgetDayDetail, TripDetailContent | `units` = **total** weight/volume (e.g., 40 lb for 2 × 20 lb) |
| **InventoryItem** | TripReceiptList, SheetView | `quantity` = **per-container** weight/volume (e.g., 20 lb each) |

This happens because `create_item_from_purchase` in `inventory.ex` computes:
```elixir
quantity_per_container = Decimal.div(purchase_units, purchase_count)
```

So if a purchase has `units=40, count=2`, the inventory item gets `quantity=20, count=2`.

## Diagnosis Steps

### Step 1: Identify the data shape

Check the component's data source:
- **Uses `Purchase` type?** → fields are `item`, `brand`, `units`, `unit_measurement`
- **Uses `InventoryItem` type?** → fields are `name`, `brand`, `quantity`, `unit_of_measure`

### Step 2: Check BaseItemEntry prop mapping

Every caller of `BaseItemEntry` must map fields correctly:

| BaseItemEntry Prop | Purchase field | InventoryItem field |
|-------------------|---------------|-------------------|
| `:name` | `purchase.item` | `item.name` |
| `:brand` | `purchase.brand` | `item.brand` |
| `:count` | `purchase.count` | `item.count` |
| `:count-unit` | `purchase.count_unit` | `item.count_unit` |
| `:units` | `purchase.units` | **`getTotalUnits(item)`** ⚠️ |
| `:unit-measurement` | `purchase.unit_measurement` | `item.unit_of_measure` |
| `:store-code` | `purchase.store_code` | `item.store_code` |
| `:total` | `purchase.total_price` | `item.total_price` |
| `:price-per-count` | `purchase.price_per_count` | `item.price_per_count` |
| `:price-per-unit` | `purchase.price_per_unit` | `item.price_per_unit` |
| `:taxable` | `purchase.taxable` | `item.taxable` |
| `:tags` | `purchase.tags` | `item.tags` |

### Step 3: Check the units computation

⚠️ **Critical**: For InventoryItem, `quantity` is per-container. You MUST compute total:

```typescript
const getTotalUnits = (item: InventoryItem) => {
  const qty = item.quantity
  const count = item.count
  if (qty != null && count != null) {
    const qtyNum = typeof qty === 'string' ? parseFloat(qty) : Number(qty)
    const countNum = typeof count === 'string' ? parseFloat(count) : Number(count)
    if (!isNaN(qtyNum) && !isNaN(countNum) && countNum > 0) {
      return String(qtyNum * countNum)
    }
  }
  return qty != null ? String(qty) : null
}
```

### Step 4: Check backend serializer completeness

When a backend endpoint serves data that feeds `BaseItemEntry`, ensure the serializer includes ALL fields:

```elixir
# Complete purchase serializer for BaseItemEntry display
defp purchase_to_json(purchase) do
  %{
    id: purchase.id,
    brand: purchase.brand,
    item: purchase.item,
    count: purchase.count,
    count_unit: purchase.count_unit,
    units: purchase.units,
    unit_measurement: purchase.unit_measurement,    # ← often missing
    price_per_count: purchase.price_per_count,
    price_per_unit: purchase.price_per_unit,
    total_price: purchase.total_price,
    store_code: purchase.store_code,                # ← often missing
    taxable: purchase.taxable,                      # ← often missing
    tags: Enum.map((purchase.tags || []), &tag_to_json/1)  # ← often missing
  }
end
```

And ensure the Ecto query preloads tags:
```elixir
preload: [:source, :tags, purchase: [:tags, stop: [:store, purchases: :tags]]]
```

## Fix Applied: BUG-0001

### Fix 1: TripReceiptList `units` computation
**File**: `client/src/components/inventory/TripReceiptList.vue`
- Added `getTotalUnits(item)` function that computes `quantity × count`
- Changed `:units="item.quantity"` to `:units="getTotalUnits(item)"`

### Fix 2: Budget entry controller serializer
**File**: `server/lib/mega_planner_web/controllers/budget_entry_controller.ex`
- Added `store_code`, `unit_measurement`, `taxable`, `tax_rate`, `tags` to `purchase_to_json`

### Fix 3: Budget entry preload chain
**File**: `server/lib/mega_planner/budget.ex`
- Changed `purchase: [stop: [:store, :purchases]]` to `purchase: [:tags, stop: [:store, purchases: :tags]]`

### Fix 4: BudgetDayDetail props
**File**: `client/src/components/budget/BudgetDayDetail.vue`
- Added `:price-per-count` and `:price-per-unit` to BaseItemEntry in expanded trip section

## Checklist for New Views

When creating a new view that displays purchase/item data:

- [ ] Determine data shape (Purchase vs InventoryItem)
- [ ] Map ALL props from the table above to BaseItemEntry
- [ ] If InventoryItem: use `getTotalUnits()` for `:units`, NOT `item.quantity`
- [ ] If InventoryItem: use `item.unit_of_measure` for `:unit-measurement`, NOT `item.unit_measurement`
- [ ] Check backend serializer includes all fields
- [ ] Check Ecto query preloads `:tags` on purchases
- [ ] Verify display matches Trip Manager view (the canonical format)
