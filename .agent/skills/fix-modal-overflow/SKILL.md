---
name: Fix Modal Overflow
description: How to diagnose and fix overflow/scroll issues in modal dialogs and inline popouts. This covers the CSS flex chain pattern, height constraint propagation, and the max-height safety net for expandable content.
---

# Fix Modal Overflow

This skill documents how to fix the common pattern where content inside a modal or popout overflows and becomes unreachable.

## Problem Pattern

A modal or popout has a `max-h-[85vh]` constraint, but when content expands (e.g., a trip's purchase list), items extend beyond the visible area with no scrollbar.

## Root Cause

The CSS `overflow: auto` only activates when a container's content exceeds its **computed height**. If the flex chain from the modal root to the scrollable area doesn't properly constrain height, `overflow-auto` does nothing.

## The Correct Flex Chain

```html
<!-- Level 1: Fixed backdrop -->
<div class="fixed inset-0 ...">

  <!-- Level 2: Modal container — MUST have max-height and flex-col -->
  <div class="max-h-[85vh] flex flex-col">

    <!-- Level 3: Header — MUST be shrink-0 -->
    <div class="shrink-0">...</div>

    <!-- Level 4: Scrollable content — MUST be flex-1 overflow-auto -->
    <div class="flex-1 overflow-auto">
      <!-- This is where tall content goes -->
    </div>

    <!-- Level 5: Footer — MUST be shrink-0 -->
    <div class="shrink-0">...</div>

  </div>
</div>
```

### Key Rules

1. **`max-h-[Xvh]` on the modal container** — this sets the ceiling
2. **`flex flex-col` on the modal container** — enables the flex chain
3. **`shrink-0` on header/footer** — they keep their size
4. **`flex-1 overflow-auto` on the content area** — it gets remaining space and scrolls
5. **`min-h-0` on flex children** — sometimes needed for the overflow to activate (flex items default to `min-height: auto` which prevents shrinking below content size)

## The Safety Net: Expandable Content

Even when the outer scroll works, **expanded sections** (like a trip's purchase list) can create very tall blocks. Add a secondary scroll constraint:

```html
<div class="max-h-[50vh] overflow-auto">
  <!-- Expandable content here -->
</div>
```

This ensures:
- The outer modal scrolls for the overall content
- The expanded section has its own max-height so it doesn't dominate the viewport

## Diagnosis Steps

### Step 1: Inspect the flex chain

Open browser DevTools, inspect the modal. Walk up from the overflowing content:

1. Does the scrollable container have `overflow: auto` or `overflow-y: auto`?
2. Does it have a **bounded height** (either explicit `max-height` or constrained by flex)?
3. Does every ancestor between the modal root and the scrollable area maintain the flex chain?

### Step 2: Check for min-height issues

If `overflow-auto` exists but doesn't scroll:
```css
/* This often fixes it */
.flex-child {
  min-height: 0; /* Override default min-height: auto */
}
```

### Step 3: Check Teleport placement

`<Teleport to="body">` can break the flex chain if the teleported content doesn't have its own height constraints. Ensure the **first child** of the Teleport has the `max-h-[Xvh]` constraint.

## Fix Applied: BUG-0002

### File: `client/src/components/budget/BudgetDayDetail.vue`

**Before:**
```html
<div v-if="entry.is_trip && isTripExpanded(entry.id)"
     class="ml-2 mt-3 space-y-3">
```

**After:**
```html
<div v-if="entry.is_trip && isTripExpanded(entry.id)"
     class="ml-2 mt-3 space-y-3 max-h-[50vh] overflow-auto">
```

The outer modal already has the correct flex chain (`max-h-[85vh] flex flex-col` → `flex-1 overflow-auto`). Adding `max-h-[50vh] overflow-auto` to the expanded section provides a secondary safety net so the purchase list is always scrollable.

## Common Locations to Check

| Component | File | Pattern |
|-----------|------|---------|
| BudgetDayDetail | `client/src/components/budget/BudgetDayDetail.vue` | Expanded trip section |
| TripDetailModal | `client/src/components/calendar/TripDetailModal.vue` | Trip detail modal |
| StoreItemEditModal | `client/src/components/budget/StoreItemEditModal.vue` | Item edit modal |
| Any inline popout | Various calendar popouts | Calendar week view overlay |

## Checklist for New Modals

- [ ] Modal container has `max-h-[Xvh]` and `flex flex-col`
- [ ] Header and footer have `shrink-0`
- [ ] Main content area has `flex-1 overflow-auto`
- [ ] Any expandable sections within content have `max-h-[Xvh] overflow-auto`
- [ ] Test with 10+ items to verify scrolling works
- [ ] Test on mobile viewport (smaller max-height)
