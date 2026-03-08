# Codebase Concerns

**Analysis Date:** 2026-03-07

## Tech Debt

**Excessive Debug Logging Left in Production Code:**
- Issue: Multiple console.log statements with `[DEBUG]` prefix left throughout client stores
- Files:
  - `client/src/stores/receipts.ts` (lines 106, 108, 114, 310, 312, 326, 338, 488)
  - `client/src/stores/calendar.ts` (lines 81, 85, 89, 101, 104, 117, 119)
  - `client/src/components/calendar/TripDetailContent.vue` (line 284)
  - `client/src/views/inventory/SheetView.vue` (line 131)
- Impact: Creates noise in browser console, may leak sensitive data about data structures, hinders debugging, signals incomplete development
- Fix approach: Create a utility logging service with log level controls (debug, info, error), replace all console.log with service calls, disable debug logging in production

**Circular Store Dependencies with Dynamic Imports:**
- Issue: Stores use `await import()` to get other stores, creating circular dependency patterns
- Files:
  - `client/src/stores/receipts.ts` imports calendar (lines 111, 128, 141), budget (lines 146, 225, 405), inventory (lines 154, 413)
  - `client/src/stores/calendar.ts` imports receipts (line 208), inventory (line 216)
  - `client/src/stores/auth.ts` imports household (lines 50, 67)
- Impact: Potential for race conditions during concurrent mutations, unpredictable import timing, harder to test and reason about data flow
- Fix approach: Introduce a centralized mutation orchestrator or event bus (Pinia actions with proper async sequencing) to coordinate state updates across stores; move cross-store updates to a middleware layer instead of inline imports

**Inconsistent Error Handling in Async Store Operations:**
- Issue: Most async operations in stores use try/finally without catch blocks, silently swallowing errors
- Files:
  - `client/src/stores/receipts.ts` - fetchTrips, fetchTrip, createPurchase all have try/finally but no error handling
  - `client/src/stores/calendar.ts` (line 121-124) only fetchTripsForPeriod has a catch that logs and empties array
  - `client/src/stores/inventory.ts` - most operations lack error handling
  - `client/src/stores/budget.ts` - fetchEntries and fetchSummary have no error handling
- Impact: API failures silently result in stale/empty state, users don't know requests failed, no way to retry, makes debugging harder
- Fix approach: Create a centralized error handler middleware, add error state to all stores, notify users via notification system on API failures, implement retry logic with exponential backoff for critical fetches

**Manual State Synchronization Between Stores:**
- Issue: Multiple stores manually sync state with each other when mutations occur, increasing complexity and risk of desynchronization
- Files:
  - `client/src/stores/receipts.ts` (lines 111-114, 128-130, 141-143, 146-150, etc.) manually syncs with calendar, budget, inventory
  - `client/src/stores/calendar.ts` (lines 208-216) manually syncs with receipts and inventory
  - `client/src/components/calendar/TripDetailContent.vue` and other components trigger cross-store actions
- Impact: Easy to miss a sync location and end up with stale data, difficult to reason about which store is the source of truth, increases mutation complexity (lines like deletePurchase span 50+ lines to sync 3 stores)
- Fix approach: Implement a single mutation listener/event system that automatically propagates changes; consider flattening to normalized store structure (similar to Redux normalized state); or use a GraphQL subscription approach

## Known Bugs

**Trip Merge Auto-Increment Bug (Unresolved):**
- Symptoms: When a purchase is created that matches an existing inventory item, the pantry quantity incorrectly increments AND the purchase is not added to the Purchases sheet
- Files:
  - Test file: `server/test/bug_repro_trip_merge_test.exs` (confirms bug reproduction)
  - Backend: `server/lib/mega_planner/receipts/purchase.ex` or inventory context (likely auto-merge logic)
- Trigger: Create trip > add purchase for item that already exists in Pantry > save
- Workaround: None - users must manually adjust Pantry quantity and re-add to correct sheet
- Impact: Data integrity issue, inventory tracking becomes unreliable

**Tag Filtering with Empty Arrays:**
- Symptoms: When filter tags list is empty, some endpoints still receive empty array parameter instead of being omitted
- Files: `client/src/stores/habits.ts` (line 56) uses ternary, but inconsistent across other stores
- Trigger: Navigate between filtered and unfiltered views
- Impact: May cause backend to filter by "no tags" instead of ignoring filter, returning incorrect data
- Fix: Standardize to `params.tag_ids = filterTags.value.length > 0 ? filterTags.value : undefined` across all stores

## Security Considerations

**Token Refresh Race Condition:**
- Risk: Multiple simultaneous 401 errors could trigger multiple token refresh attempts before the first one completes
- Files: `client/src/services/api.ts` (lines 70-118) has inflight deduplication but only within request lifetime
- Current mitigation: `isRefreshing` flag and `refreshPromise` tracking prevent multiple simultaneous refreshes
- Recommendations: Add request queue to ensure refreshed token is applied before retrying; add timeout to refresh attempt so hung requests don't block entire app

**No Input Validation on Store Mutations:**
- Risk: Store actions accept Partial<T> with minimal validation, allowing invalid data to be sent to API
- Files: All store mutation methods (e.g., `createItem`, `updateEntry`, `createPurchase`)
- Current mitigation: Backends likely validate, but client doesn't prevent malformed requests
- Recommendations: Add zod/valibot schemas to validate mutation payloads before API calls

**Console Log May Leak Sensitive Data:**
- Risk: Debug logs in receipts.ts and calendar.ts log full JSON objects including potentially sensitive financial data
- Files: `client/src/stores/receipts.ts` (lines 106-108, 310-318), `client/src/stores/calendar.ts` (lines 81, 104)
- Current mitigation: Only visible in dev console
- Recommendations: Remove all console.log before production deployment; use structured logging with redaction of sensitive fields

## Performance Bottlenecks

**Large API Response Deserialization:**
- Problem: API responses are large objects with nested purchases/items, deserialized into JS objects without streaming or pagination
- Files:
  - `client/src/services/api.ts` - all list endpoints return full arrays
  - `client/src/stores/receipts.ts` - trips.value can contain hundreds of stops with thousands of purchases
  - `client/src/stores/calendar.ts` - tripsByDate computed property iterates all trips on every change
- Cause: No pagination, no lazy loading, Vue computed properties recalculate on every store change
- Improvement path: Add pagination to API endpoints, implement virtual scrolling in list views, memoize computed properties with `computed` from @vue/composition-api or `useComputed` with deps

**Prefetch Cache Staleness Threshold Too Conservative:**
- Problem: 15-second stale threshold means data can be up to 15 seconds old; in real-time collaborative scenarios this causes visible desync
- Files: `client/src/utils/prefetch.ts` (line 12) - `STALE_THRESHOLD_MS = 15_000`
- Cause: Static threshold doesn't account for mutation frequency
- Improvement path: Make threshold configurable per route, reduce for high-mutation areas (trips/purchases), increase for static data (stores list)

**Computed Properties Cause Cascading Re-renders:**
- Problem: `tripsByDate`, `tasksByDate`, `entriesByDate` computed properties sort/group entire arrays on every store change
- Files:
  - `client/src/stores/calendar.ts` (lines 79-91)
  - `client/src/stores/budget.ts` (lines 25-32)
  - `client/src/stores/calendar.ts` (lines 64-76)
- Cause: Reactive arrays change trigger full recomputation, components watching these props re-render entire lists
- Improvement path: Use `markRaw` for non-reactive grouping maps, implement windowing/virtual scrolling for large lists, consider moving sorting to backend

**Receipt Store Grows Without Bounds:**
- Problem: `purchases.value` array grows indefinitely, never cleared or paginated
- Files: `client/src/stores/receipts.ts` (lines 14, 319, 351, 379) - purchases.value keeps all fetched purchases
- Cause: No pagination or archival mechanism
- Improvement path: Implement LRU eviction (keep only last 100 purchases in memory), add pagination to API, implement infinite scroll with intersection observer

## Fragile Areas

**Receipts Store State Synchronization (560 lines):**
- Files: `client/src/stores/receipts.ts`
- Why fragile:
  - Manages 7 pieces of state (stores, trips, currentTrip, brands, units, purchases, drivers)
  - Every mutation must manually sync with 3 other stores (calendar, budget, inventory)
  - Manual array index operations prone to off-by-one errors (e.g., lines 351-366)
  - Cross-store imports create coupling and circular dependency risks
  - No invariant checking to ensure currentTrip.stops[i].purchases stays in sync with purchases.value
- Safe modification:
  - Add unit tests for all sync operations before modifying
  - Create snapshot tests to verify all store states after mutations
  - Add assertions on mutation exit (e.g., `currentTrip.stops.every(s => s.purchases.length > 0)`)
  - Consider extracting to separate stores per domain (TripsStore, PurchasesStore)
- Test coverage: Manual QA of trip operations; cross-store integration tests missing

**Dynamic Store Imports in Calendar and Receipts:**
- Files:
  - `client/src/stores/calendar.ts` (lines 208, 216)
  - `client/src/stores/receipts.ts` (lines 111, 128, 141, 146, 154, 216, 225, 233, 333, 400, 405, 413, 483)
- Why fragile:
  - Import ordering is unpredictable (async)
  - If imported store is not yet initialized, may get undefined
  - Can create infinite loops if store A imports B and B imports A
  - Hard to trace data dependencies with static analysis
- Safe modification: Add runtime guards to check store existence before use; add console warnings if circular import detected; prefer event bus pattern instead
- Test coverage: No tests for concurrent mutations across stores

**Calendar TasksStore Computed Properties with Console.log:**
- Files: `client/src/stores/calendar.ts` (lines 81-91, tripsByDate with debug logging)
- Why fragile:
  - Computed properties execute on every dependency change
  - Debug logging inside computed properties adds overhead and noise
  - Sorting by trip.id or date is unpredictable if date fields are missing
  - No error handling if trip lacks trip_start date (falls back to inserted_at with silent string split)
- Safe modification: Add null coalescing with defensive checks, extract logging to separate debug function, test with trips missing dates
- Test coverage: No tests for edge cases (missing trip_start, null trip_id)

**Budget Day Detail Modal with Expanded Trip Scrolling (Recently Fixed):**
- Files: `client/src/components/budget/BudgetDayDetail.vue`
- Why fragile:
  - Fixed with `max-h-[50vh] overflow-auto` but this is fragile if content grows beyond 50vh
  - Nested flex containers make height constraints brittle (needs `min-h-0` on all flex children)
  - Teleport to fixed position modal can break if parent container has overflow hidden
  - Different browser scrollbar widths can cause layout shifts
- Safe modification: Add tests for various trip sizes (5, 10, 20+ purchases); verify scroll appears/works in all browsers; use CSS-in-JS to dynamically set max-height based on viewport
- Test coverage: Manual testing only; no automated scroll behavior tests

## Scaling Limits

**Trips List Size:**
- Current capacity: API returns all trips for date range, no pagination
- Limit: UI begins to stutter around 100+ trips with 5+ stops each; `tripsByDate` computed property loops all trips
- Scaling path: Implement pagination (load 50 trips at a time), add virtual scrolling in trip list, implement lazy-load for stops within each trip

**Purchases Per Stop:**
- Current capacity: All purchases rendered when trip is expanded, no pagination
- Limit: UI becomes sluggish at 20+ items per stop due to BaseItemEntry rendering cost
- Scaling path: Add pagination to purchase lists, implement virtual list for expanded purchases, cache BaseItemEntry rendered output

**Budget Entries Per Month:**
- Current capacity: All entries fetched for entire month, no pagination
- Limit: Performance degrades at 1000+ entries due to `entriesByDate` grouping and rendering
- Scaling path: Add pagination to budget entries, implement daily grouping on backend, use virtual scrolling

**Concurrent Mutations Across Stores:**
- Current capacity: Sequential mutations work fine, concurrent mutations risk desynchronization
- Limit: If user rapidly creates trip + adds purchase + modifies budget, race conditions likely
- Scaling path: Implement mutation queue/coordinator, use optimistic updates, add conflict resolution for concurrent changes

## Dependencies at Risk

**date-fns Usage Without Tree-Shaking:**
- Risk: date-fns is large (~35KB gzipped), and selective imports are used but tree-shaking may not be optimal
- Files:
  - `client/src/stores/calendar.ts` imports 7 functions
  - `client/src/stores/budget.ts` imports 5 functions
  - Usage across multiple stores
- Impact: Bundle size may be larger than necessary
- Migration plan: Audit date-fns imports, consider migrating to tiny date lib (date-fns-minimal or use standard Date + helpers), or use native JS Date with careful handling

**Pinia for Complex State Management:**
- Risk: Pinia works well for simple stores but multi-store orchestration is handled manually
- Files: All stores in `client/src/stores/`
- Impact: As app grows, manual sync becomes unmaintainable; Pinia doesn't prevent race conditions or circular dependencies
- Migration plan: If complexity grows, consider GraphQL + Apollo Client for automatic cache invalidation, or Redux-like architecture with explicit middleware

**Legacy Support: setToken and setTokens in API Client:**
- Risk: Both setToken and setTokens exist, confusion about which to use
- Files: `client/src/services/api.ts` (lines 52-68)
- Impact: Code maintainers may use wrong method, tokens may not be tracked correctly
- Migration plan: Remove setToken (legacy), rename setTokens to setToken, update all callers

## Missing Critical Features

**No Request Cancellation on Route Changes:**
- Problem: Inflight API requests complete even after user navigates away, potentially updating wrong view state
- Blocks: Users can't quickly navigate between views without loading spinners completing
- Impact: High: Could cause stale updates, wasted bandwidth, battery drain on mobile
- Fix: Implement AbortController per request, cancel on route change

**No Offline Mode / Optimistic Updates:**
- Problem: All mutations are pessimistic (wait for server response), no optimistic update support
- Blocks: Poor UX on slow connections, users must wait for every action
- Impact: Medium: UX degradation on mobile
- Fix: Add optimistic update pattern (update UI immediately, revert on error)

**No Data Validation on Backend Responses:**
- Problem: API responses assume correct schema, no runtime validation
- Blocks: Type mismatches between backend and frontend go undetected until rendering
- Impact: Medium: Silent data corruption if backend schema changes
- Fix: Add zod/valibot schema validation on all API responses

**No Soft Deletion / Undo for Destructive Actions:**
- Problem: Delete operations are permanent, no undo
- Blocks: Users can't recover from accidental deletes
- Impact: Low: Affects user experience, not functionality
- Fix: Implement soft delete with recovery window (7 days)

## Test Coverage Gaps

**Cross-Store Mutation Synchronization:**
- What's not tested: When receipts store creates trip, does calendar store get updated correctly? Does budget store reflect changes?
- Files: `client/src/stores/receipts.ts` (all mutation methods), sync happens implicitly
- Risk: Silent desynchronization bugs
- Priority: High - this is the most fragile part of the codebase

**Error Handling in Async Store Operations:**
- What's not tested: API failures, timeouts, network errors; how do stores behave?
- Files: All stores in `client/src/stores/`
- Risk: Users see loading spinner forever, or silent data loss
- Priority: High - core reliability concern

**Prefetch Cache Behavior:**
- What's not tested: Does cache staleness work correctly? Are race conditions between manual fetch and route-based prefetch handled?
- Files: `client/src/utils/prefetch.ts`, usage in all stores
- Risk: Stale data served when user expects fresh data
- Priority: Medium - data freshness is important

**API Client Token Refresh Edge Cases:**
- What's not tested: What happens if refresh token is expired? What if refresh endpoint returns error? What if multiple requests get 401 simultaneously?
- Files: `client/src/services/api.ts` (lines 70-118)
- Risk: Users get logged out unexpectedly, 401 loops, broken state
- Priority: High - authentication is critical

**Virtual Scrolling / Large List Rendering:**
- What's not tested: How does UI perform with 100+ trips, 50+ purchases per trip?
- Files: All components rendering lists (PurchaseList, TripReceiptList, BudgetDayDetail)
- Risk: Performance degradation, janky UI
- Priority: Low - only affects large datasets

**Budget Entry Grouping and Display:**
- What's not tested: Does entriesByDate group correctly? Do budget totals match database aggregates?
- Files: `client/src/stores/budget.ts`, `client/src/components/budget/BudgetDayDetail.vue`
- Risk: Incorrect financial summaries
- Priority: High - financial data must be accurate

---

*Concerns audit: 2026-03-07*
