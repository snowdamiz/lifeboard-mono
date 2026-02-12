---
name: Prefetch Data
description: How to preload Pinia store data ahead of navigation so views render instantly with no loading spinners or flicker. Covers router-level prefetching, hover-based prefetching, store staleness guards, and in-view eager loading for tabs and sub-views.
---

# Prefetch Data Skill

This skill eliminates perceived lag when a user clicks a sidebar tab, opens a modal, or switches sub-views. The core idea: **start fetching data _before_ the target view mounts**, so by the time the component runs its `onMounted`, the store already has fresh data and no spinner appears.

---

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Architecture Overview](#architecture-overview)
3. [Technique 1 — Router-Level Prefetch (beforeResolve)](#technique-1--router-level-prefetch-beforeresolve)
4. [Technique 2 — Hover / Pointerdown Prefetch](#technique-2--hover--pointerdown-prefetch)
5. [Technique 3 — Store Staleness Guard](#technique-3--store-staleness-guard)
6. [Technique 4 — Eager Sub-View Loading (Tab Prefetch)](#technique-4--eager-sub-view-loading-tab-prefetch)
7. [Technique 5 — AppShell Boot Prefetch](#technique-5--appshell-boot-prefetch)
8. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
9. [Store-by-Store Prefetch Reference](#store-by-store-prefetch-reference)
10. [Checklist for Adding Prefetch to a New Feature](#checklist-for-adding-prefetch-to-a-new-feature)

---

## Problem Statement

Every view in Lifeboard currently fetches its store data inside `onMounted`. This means:

1. User clicks a sidebar link (e.g., "Inventory").
2. Vue Router renders the new component.
3. `onMounted` fires → API call begins → `loading = true` → **spinner appears** → API responds → data renders.

The spinner flash (even if only 100–300ms) creates a *jarring, unpolished* feel. The fix is to overlap the API call with the navigation so that data is already present when the component renders.

---

## Architecture Overview

```
                         ┌─── Technique 1: Router beforeResolve ───┐
                         │     fires DURING route transition       │
User clicks              │     fetches store data in parallel      │
sidebar link ─────────►  │     new view mounts with data ready     │
                         └─────────────────────────────────────────┘

                         ┌─── Technique 2: Hover Prefetch ─────────┐
                         │     @pointerenter on <RouterLink>       │
User hovers              │     starts the fetch early (100ms delay)│
sidebar link ─────────►  │     by click time, data may already be  │
                         │     in store                            │
                         └─────────────────────────────────────────┘

                         ┌─── Technique 3: Staleness Guard ────────┐
                         │     Store tracks `lastFetchedAt`        │
onMounted still          │     if data is recent, skip re-fetch    │
calls fetchXxx() ──────► │     if stale, fetch normally            │
                         │     eliminates redundant API calls      │
                         └─────────────────────────────────────────┘
```

**All three techniques work together.** Technique 3 is the safety net that prevents double-fetching if the prefetch already loaded the data.

---

## Technique 1 — Router-Level Prefetch (beforeResolve)

### Where to Implement

`client/src/router/index.ts`

### How It Works

Use `router.beforeResolve()` (fires after `beforeEach` guards pass, but before the new component renders) to kick off store fetches based on the destination route:

```ts
// In router/index.ts, AFTER the existing beforeEach guard:

router.beforeResolve(async (to) => {
  // Import stores lazily (Pinia is already initialized by this point)
  const { useCalendarStore } = await import('@/stores/calendar')
  const { useBudgetStore } = await import('@/stores/budget')
  const { useInventoryStore } = await import('@/stores/inventory')
  const { useGoalsStore } = await import('@/stores/goals')
  const { useHabitsStore } = await import('@/stores/habits')
  const { useNotesStore } = await import('@/stores/notes')
  const { useTagsStore } = await import('@/stores/tags')

  // Fire-and-forget: start fetching, don't await
  // The view's onMounted will use the staleness guard (Technique 3)
  // to avoid a double-fetch
  switch (to.name) {
    case 'dashboard': {
      const cal = useCalendarStore()
      const inv = useInventoryStore()
      const bud = useBudgetStore()
      cal.fetchTodayTasks()
      inv.fetchSheets()
      bud.fetchSummary()
      break
    }
    case 'calendar':
    case 'calendar-day': {
      const cal = useCalendarStore()
      cal.fetchCurrentViewTasks()
      break
    }
    case 'inventory': {
      const inv = useInventoryStore()
      inv.fetchSheets()
      break
    }
    case 'inventory-sheet': {
      const inv = useInventoryStore()
      if (to.params.id) inv.fetchSheet(to.params.id as string)
      break
    }
    case 'shopping-list': {
      const inv = useInventoryStore()
      inv.fetchShoppingLists()
      break
    }
    case 'budget': {
      const bud = useBudgetStore()
      bud.fetchSources()
      bud.fetchMonthEntries()
      bud.fetchSummary()
      break
    }
    case 'goals': {
      const goals = useGoalsStore()
      goals.fetchGoals()
      break
    }
    case 'habits': {
      const habits = useHabitsStore()
      habits.fetchHabits()
      habits.fetchHabitInventories()
      break
    }
    case 'notes': {
      const notes = useNotesStore()
      notes.fetchNotebooks()
      break
    }
    case 'tags': {
      const tags = useTagsStore()
      tags.fetchTags()
      break
    }
  }
})
```

### Key Points

- **Fire-and-forget**: Do NOT `await` the fetches. The navigation should proceed immediately. If the fetch finishes before the component mounts, the view will have data; if it doesn't finish in time, the view's own `onMounted` will wait for the same promise (dedup'd by the staleness guard).
- **Dynamic imports**: Use `await import(...)` for the store modules to keep the router file lightweight and avoid circular imports.
- **Switch on `to.name`**: Use the route _name_, not path, for robustness.

---

## Technique 2 — Hover / Pointerdown Prefetch

### Where to Implement

`client/src/components/layout/Sidebar.vue` (and `MobileNav.vue`)

### How It Works

On `@pointerenter` of each `<RouterLink>`, schedule the same prefetch with a short delay. If the user hovers ~200ms before clicking, the fetch starts early.

```html
<RouterLink
  :to="item.path"
  @pointerenter="schedulePrefetch(item.id)"
  @pointerleave="cancelPrefetch"
>
```

```ts
import { prefetchForRoute } from '@/utils/prefetch'

let prefetchTimer: ReturnType<typeof setTimeout> | null = null

const schedulePrefetch = (routeId: string) => {
  cancelPrefetch()
  prefetchTimer = setTimeout(() => {
    prefetchForRoute(routeId)
  }, 100) // 100ms delay to avoid triggering on quick mouse passes
}

const cancelPrefetch = () => {
  if (prefetchTimer) {
    clearTimeout(prefetchTimer)
    prefetchTimer = null
  }
}
```

### Shared Prefetch Utility

Create `client/src/utils/prefetch.ts` to centralize the prefetch logic so it can be used by both the router guard and hover handlers:

```ts
// client/src/utils/prefetch.ts

/**
 * Trigger data prefetch for a given route identifier.
 * This is fire-and-forget — callers should NOT await this.
 * The staleness guard in each store prevents double-fetching.
 */
export function prefetchForRoute(routeId: string) {
  switch (routeId) {
    case 'dashboard': {
      import('@/stores/calendar').then(m => m.useCalendarStore().prefetch())
      import('@/stores/inventory').then(m => m.useInventoryStore().prefetch())
      import('@/stores/budget').then(m => m.useBudgetStore().prefetch())
      break
    }
    case 'calendar': {
      import('@/stores/calendar').then(m => m.useCalendarStore().prefetch())
      break
    }
    case 'inventory': {
      import('@/stores/inventory').then(m => m.useInventoryStore().prefetch())
      break
    }
    case 'shopping-list': {
      import('@/stores/inventory').then(m => {
        const store = m.useInventoryStore()
        store.fetchShoppingListsIfStale()
      })
      break
    }
    case 'budget': {
      import('@/stores/budget').then(m => m.useBudgetStore().prefetch())
      break
    }
    case 'goals': {
      import('@/stores/goals').then(m => m.useGoalsStore().prefetch())
      break
    }
    case 'habits': {
      import('@/stores/habits').then(m => m.useHabitsStore().prefetch())
      break
    }
    case 'notes': {
      import('@/stores/notes').then(m => m.useNotesStore().prefetch())
      break
    }
    case 'tags': {
      import('@/stores/tags').then(m => m.useTagsStore().prefetch())
      break
    }
  }
}
```

---

## Technique 3 — Store Staleness Guard

### The Problem

If the router prefetches and the view's `onMounted` also fetches, the same API call fires twice. We need deduplication.

### Solution: `lastFetchedAt` + `isFresh()` + Inflight Promise Caching

Add these fields and helpers to every Pinia store that participates in prefetching:

```ts
// Example: adding staleness guard to inventory.ts

const STALE_THRESHOLD_MS = 15_000 // 15 seconds — data older than this is considered stale

// Tracks the last successful fetch time per "fetch key"
const lastFetchedAt = ref<Record<string, number>>({})

// Tracks in-flight promises to deduplicate concurrent calls
const inflightRequests = ref<Record<string, Promise<void>>>({})

function isFresh(key: string): boolean {
  const ts = lastFetchedAt.value[key]
  if (!ts) return false
  return Date.now() - ts < STALE_THRESHOLD_MS
}

// Wraps any fetch function with staleness check + inflight dedup
async function fetchIfStale(key: string, fetchFn: () => Promise<void>) {
  // If data is fresh, skip
  if (isFresh(key)) return

  // If this exact fetch is already in-flight, wait for it (dedup)
  if (inflightRequests.value[key]) {
    return inflightRequests.value[key]
  }

  // Start the fetch
  const promise = fetchFn().then(() => {
    lastFetchedAt.value[key] = Date.now()
  }).finally(() => {
    delete inflightRequests.value[key]
  })

  inflightRequests.value[key] = promise
  return promise
}

// Example usage inside the store:
async function fetchSheets() {
  return fetchIfStale('sheets', async () => {
    loading.value = true
    try {
      const response = await api.listSheets({ ... })
      sheets.value = response.data
    } finally {
      loading.value = false
    }
  })
}

// Convenience method for the prefetch utility:
function prefetch() {
  fetchSheets() // fire-and-forget; staleness guard handles dedup
}
```

### When to Invalidate

After **any mutation** (create, update, delete), clear the relevant staleness key:

```ts
async function createSheet(name: string) {
  const response = await api.createSheet({ name })
  delete lastFetchedAt.value['sheets'] // Invalidate cache
  await fetchSheets() // Re-fetch with fresh data
  return response.data
}
```

### The `STALE_THRESHOLD_MS` Value

- **15 seconds** is a good default — it covers the window between a prefetch and a mount.
- Views that show rapidly-changing data (e.g., habits with optimistic updates) can use a shorter threshold.
- The threshold should NEVER be so long that stale data would mislead the user. The guard is purely a **dedup mechanism**, not a cache.

---

## Technique 4 — Eager Sub-View Loading (Tab Prefetch)

### The Problem

Some views have internal tabs (e.g., Habits → "Inventory" tab vs "Calendar" tab). Switching tabs often triggers `onMounted` for a sub-component that fetches different data.

### Solution: Fetch All Tab Data on Parent Mount

When the parent component mounts, fetch data for **all** tabs, not just the initially visible one:

```ts
// In HabitsView.vue onMounted:
onMounted(async () => {
  await Promise.all([
    habitsStore.fetchHabits(),
    habitsStore.fetchHabitInventories(),
    // Also pre-fetch analytics for the Calendar tab:
    habitsStore.fetchHabitAnalytics()
  ])
})
```

### For Modals / Inline Popouts

When a component renders a "Manage Trip" button that opens an inline popout, prefetch the trip data on the button's `@pointerenter`:

```html
<Button
  @click="handleOpenTripDetail(tripId)"
  @pointerenter="prefetchTrip(tripId)"
>
  Manage
</Button>
```

```ts
const prefetchTrip = (tripId: string) => {
  receiptsStore.fetchTrip(tripId) // fire-and-forget
}
```

---

## Technique 5 — AppShell Boot Prefetch

### Where to Implement

`client/src/components/layout/AppShell.vue`

### How It Works

When the AppShell first mounts (after auth is confirmed), prefetch the most commonly needed data immediately:

```ts
// In AppShell.vue
onMounted(() => {
  // Tags are used everywhere (filter dropdowns)
  const tagsStore = useTagsStore()
  tagsStore.fetchTags()

  // Preferences are needed for sidebar order + dashboard layout
  const preferencesStore = usePreferencesStore()
  preferencesStore.fetchPreferences()
})
```

This ensures that tags and preferences are **always** warm by the time any view renders, since every view that has a tag filter needs tag data.

---

## Anti-Patterns to Avoid

### ❌ Awaiting Prefetch in the Router Guard (`beforeResolve`)

```ts
// BAD — blocks navigation until the API call resolves
router.beforeResolve(async (to) => {
  await calendarStore.fetchCurrentViewTasks() // ← BLOCKS
})
```
This defeats the purpose. If the API is slow, the whole app feels frozen. Always fire-and-forget.

### ❌ Removing `onMounted` Fetches from Views

```ts
// BAD — relying solely on the router prefetch
// onMounted(() => { }) // ← removed
```
The router prefetch is an **optimization**, not a guarantee. If the user bookmarks a deep link, refreshes the page, or the prefetch encounters an error, the view's `onMounted` is the fallback. Always keep it, guarded by `fetchIfStale`.

### ❌ Prefetching Everything on App Boot

```ts
// BAD — loads way too much data before the user needs it
onMounted(() => {
  calendarStore.fetchAllData()
  budgetStore.fetchAllData()
  inventoryStore.fetchAllData()
  goalsStore.fetchAllData()
  habitsStore.fetchAllData()
  notesStore.fetchAllData()
})
```
This wastes bandwidth and slows down initial load. Only prefetch **tags** and **preferences** on boot. Everything else should be lazy (route-triggered or hover-triggered).

### ❌ Setting `STALE_THRESHOLD_MS` Too High

A threshold of 5 minutes means the user could see stale data after making changes in another part of the app. 15 seconds is the sweet spot for dedup without staleness risk.

### ❌ Caching Through Page Refreshes

This system is **in-memory only** (Pinia refs). Data does not survive a hard refresh — that's by design. The staleness guard only prevents redundant calls within a single session.

---

## Store-by-Store Prefetch Reference

| Store | Route Trigger | Prefetch Functions | Notes |
|-------|--------------|-------------------|-------|
| `calendar` | `calendar`, `calendar-day`, `dashboard` | `fetchCurrentViewTasks()`, `fetchTodayTasks()` | Fetches are date-range scoped; staleness key should include the date range |
| `budget` | `budget`, `dashboard` | `fetchSources()`, `fetchMonthEntries()`, `fetchSummary()` | Also fetch `fetchTripsForPeriod()` for the budget calendar |
| `inventory` | `inventory`, `dashboard` | `fetchSheets()` | Individual sheet fetched by ID on `inventory-sheet` route |
| `goals` | `goals` | `fetchGoals()` | Filter tags reset on mount — prefetch should respect current filter state |
| `habits` | `habits` | `fetchHabits()`, `fetchHabitInventories()` | Two parallel calls needed |
| `notes` | `notes` | `fetchNotebooks()` | Individual pages fetched on `page` route |
| `tags` | ALL (via AppShell boot) | `fetchTags()` | Always warm — used by every filter dropdown |
| `receipts` | `trips`, `budget` | `fetchTrips()` | Heavy payload; only fetch on direct navigation |
| `preferences` | ALL (via AppShell boot) | `fetchPreferences()` | Controls sidebar order + dashboard layout |

---

## Checklist for Adding Prefetch to a New Feature

When you add a new page, tab, or modal that loads data:

- [ ] **Add a staleness guard** to the store's fetch function (`fetchIfStale` wrapper)
- [ ] **Add prefetch entry** in `prefetchForRoute()` in `client/src/utils/prefetch.ts`
- [ ] **Add route case** in `router.beforeResolve()` if it's a top-level route
- [ ] **Add hover handler** on the sidebar `<RouterLink>` or mobile nav if applicable
- [ ] **Keep `onMounted` fetch** in the view as a fallback (guarded by staleness)
- [ ] **Invalidate staleness** after mutations (create/update/delete)
- [ ] **Test with network throttling** (Chrome DevTools → "Slow 3G") to verify the spinner either doesn't appear or appears only briefly
- [ ] **Test deep linking** — navigating directly to a URL should still fetch data correctly
- [ ] **Test that mutations properly invalidate** — after creating/editing/deleting, navigating away and back should show fresh data

---

## Implementation Priority

When adding prefetch to the codebase, implement in this order:

1. **Staleness guard infrastructure** (Technique 3) — add `fetchIfStale` to every store. This is the foundation that prevents double-fetching and makes all other techniques safe.
2. **AppShell boot prefetch** (Technique 5) — warm up tags and preferences globally.
3. **Router-level prefetch** (Technique 1) — the biggest impact for the least code.
4. **Hover prefetch** (Technique 2) — noticeable polish for desktop users.
5. **Tab/modal eager loading** (Technique 4) — per-feature; add as needed.
