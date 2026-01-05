---
name: Feature Enhancements Plan
overview: "This plan addresses 8 feature requests and bug fixes: custom goal categories/tags, tab ordering, dashboard customization, multiple shopping lists, a task count bug fix, habit uncomplete fix, goal history screen, and goal filtering/sorting."
todos:
  - id: habit-uncomplete-fix
    content: "Fix habit uncomplete: add API method and update store to use DELETE endpoint"
    status: completed
  - id: dashboard-task-bug
    content: Fix dashboard task count bug by separating today's tasks from calendar date range
    status: completed
  - id: goal-categories-backend
    content: Create GoalCategory schema, migration, and CRUD endpoints
    status: completed
  - id: goal-categories-frontend
    content: Add category management UI and update goal forms
    status: completed
    dependencies:
      - goal-categories-backend
  - id: goal-tags
    content: Add tags support to goals (join table + API updates)
    status: completed
    dependencies:
      - goal-categories-backend
  - id: goal-filtering
    content: Add filtering and sorting UI to GoalsView
    status: completed
    dependencies:
      - goal-categories-frontend
      - goal-tags
  - id: goal-history-backend
    content: Create GoalStatusChange schema and history tracking
    status: completed
  - id: goal-history-frontend
    content: Create GoalHistoryView with timeline display
    status: completed
    dependencies:
      - goal-history-backend
  - id: user-preferences
    content: Add user preferences infrastructure (backend + frontend store)
    status: completed
  - id: tab-ordering
    content: Make sidebar tabs draggable with persistent ordering
    status: completed
    dependencies:
      - user-preferences
  - id: shopping-lists-backend
    content: Create ShoppingList schema and update endpoints for multiple lists
    status: completed
  - id: shopping-lists-frontend
    content: Update shopping list UI for multiple lists with manual item add
    status: completed
    dependencies:
      - shopping-lists-backend
  - id: dashboard-widgets
    content: Create widget system with draggable grid layout
    status: completed
    dependencies:
      - user-preferences
---

# Mega-Planner Feature Enhancements

## 1. Custom Goal Categories, Subcategories, and Tags

**Current state:** Goals have a simple `category` string field with hardcoded options in [`client/src/views/goals/GoalsView.vue`](client/src/views/goals/GoalsView.vue) (line 29).

**Changes:**

Backend:
- Create new `GoalCategory` schema in `server/lib/mega_planner/goals/` with fields: `id`, `name`, `parent_id` (nullable for subcategories), `color`, `household_id`
- Add migration for `goal_categories` table
- Add `goal_category_id` field to goals table (nullable, replacing string `category`)
- Associate goals with Tags (many-to-many via join table, similar to how inventory items work)
- Add CRUD endpoints for goal categories

Frontend:
- Add category management UI in Settings or Goals view
- Update goal create/edit forms to use dynamic categories
- Add `TagSelector` component (already exists) to goal forms
- Update `types/index.ts` to include `GoalCategory` type

## 2. Customizable Tab/Navigation Ordering

**Current state:** Fixed `navItems` array in [`client/src/components/layout/Sidebar.vue`](client/src/components/layout/Sidebar.vue) (lines 19-30).

**Changes:**

Backend:
- Add `preferences` JSONB field to users table (or new `user_preferences` table)
- Store `nav_order` as array of tab IDs
- Add API endpoints to get/update user preferences

Frontend:
- Create `usePreferencesStore` to manage user preferences
- Make sidebar tabs draggable using a drag-and-drop library
- Persist order changes to backend
- Update [`MobileNav.vue`](client/src/components/layout/MobileNav.vue) to use same ordering

## 3. Customizable Dashboard

**Current state:** Fixed layout in [`client/src/views/DashboardView.vue`](client/src/views/DashboardView.vue).

**Changes:**

Backend:
- Store dashboard layout in user preferences: `dashboard_widgets` (array of widget configs with position, size, visibility)
- Define available widget types: tasks_today, inventory_status, budget_summary, habits_progress, goals_progress, etc.

Frontend:
- Create widget system with pluggable components
- Add drag-and-drop grid layout (using vue-grid-layout or similar)
- Add "Edit Dashboard" mode with add/remove widget controls
- Create individual widget components for each data type
- Save layout changes to preferences

## 4. Multiple Shopping Lists

**Current state:** Single auto-generated list in [`client/src/views/inventory/ShoppingListView.vue`](client/src/views/inventory/ShoppingListView.vue) and [`client/src/stores/inventory.ts`](client/src/stores/inventory.ts).

**Changes:**

Backend:
- Create `ShoppingList` schema with `id`, `name`, `is_auto_generated`, `household_id`
- Update `ShoppingListItem` to belong to a `ShoppingList`
- Modify generate endpoint to create/update items in a designated "Auto-Generated" list
- Add CRUD endpoints for shopping lists
- Add endpoint to manually add items to any list

Frontend:
- Update shopping list view to show list selector/tabs
- Add "Create New List" button
- Allow manual item addition to any list
- Keep "Generate from Inventory" for auto-generated list only

## 5. Fix Dashboard Task Count Bug

**Current state:** Dashboard's `todaysTasks` computed property reads from `calendarStore.tasksByDate` which gets replaced when navigating to Calendar and selecting different dates.

**Bug location:** [`client/src/views/DashboardView.vue`](client/src/views/DashboardView.vue) lines 21-24 use shared calendar store state.

**Fix:**
- In [`client/src/stores/calendar.ts`](client/src/stores/calendar.ts), maintain a separate `todaysTasks` ref that is only updated when explicitly fetching today's data
- Or: Have Dashboard make its own API call for today's tasks independent of calendar store
- Ensure task fetches don't clear existing data for other date ranges

## 6. Fix Habit Uncomplete Feature

**Current state:** Backend supports uncomplete via `DELETE /habits/:id/complete` ([`router.ex`](server/lib/mega_planner_web/router.ex) line 103), but frontend [`habits.ts`](client/src/stores/habits.ts) `uncompleteHabit` function (line 87) incorrectly calls `api.updateHabit()`.

**Fix:**

API Client ([`api.ts`](client/src/services/api.ts)):
- Add `uncompleteHabit(id: string)` method that calls `DELETE /habits/${id}/complete`

Store ([`habits.ts`](client/src/stores/habits.ts)):
- Update `uncompleteHabit` function to call the new API method instead of `updateHabit`

## 7. Goal History Screen

**Current state:** Completed goals shown in "Completed" tab of [`GoalsView.vue`](client/src/views/goals/GoalsView.vue) but no detailed history view.

**Changes:**

Backend:
- Create `GoalStatusChange` schema to track status transitions with timestamps
- Add migration for `goal_status_changes` table
- Record status changes in `update_goal` function
- Add endpoint to fetch goal history

Frontend:
- Create new `GoalHistoryView.vue` with timeline display
- Show goal status changes, milestone completions with dates
- Add navigation from Goals page to history view
- Consider adding history tab in `GoalDetailView.vue`

## 8. Goal List Filtering and Sorting

**Current state:** Goals displayed in a simple list with Active/Completed tabs.

**Changes:**

Frontend ([`GoalsView.vue`](client/src/views/goals/GoalsView.vue)):
- Add filter dropdowns for category, subcategory, tags
- Add sort options: by date, category, progress, title
- Store filter/sort preferences in local state or preferences
- Update computed `displayedGoals` to apply filters and sorting

Backend:
- Add query parameters to `GET /goals` for filtering by category_id, tag_ids
- Add sorting parameter support

---

## Implementation Order

The recommended order minimizes dependencies:

1. **Habit Uncomplete Fix** (5 min) - Simple API fix
2. **Dashboard Task Count Bug** (30 min) - Independent fix
3. **Goal Categories/Tags** (backend first, then frontend)
4. **Goal Filtering/Sorting** (depends on #3)
5. **Goal History** (can parallel with #3-4)
6. **User Preferences Infrastructure** (needed for #7-8)
7. **Tab Ordering** (depends on #6)
8. **Multiple Shopping Lists**
9. **Dashboard Customization** (most complex, do last)