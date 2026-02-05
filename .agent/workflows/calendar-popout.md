---
description: How to implement full-width inline popouts in calendar weekly view (like task editor and trip manager)
---

# Full-Width Calendar Popouts Skill

This skill describes how to implement full-width inline popouts that span all 7 columns in the weekly calendar view.

## Pattern Overview

The weekly calendar view uses a **7-column grid layout**. When editing a task or managing a trip, the content should expand to fill the entire grid width rather than appearing as a centered modal dialog.

## Architecture

### Key Files
- `client/src/views/calendar/CalendarView.vue` - Main calendar with week grid
- `client/src/components/calendar/TaskDetailPopout.vue` - Full-width task editor
- `client/src/components/calendar/TripDetailModal.vue` - Full-width trip manager (with `inline-mode` prop)

### State Management

```typescript
// For task editing popout
const editingTask = ref<Task | null>(null)
const editingDayIndex = ref<number | null>(null)

// For trip detail popout
const showInlineTripDetail = ref(false)
const selectedTripId = ref<string | null>(null)
```

## Implementation Pattern

### Step 1: Create the Overlay Container

Inside the 7-column grid container, add an absolute positioned overlay:

```vue
<div class="flex-1 grid grid-cols-7 relative">
  <!-- Full-width popout overlay -->
  <div 
    v-if="editingTask"
    class="absolute inset-0 z-30 bg-card border border-white/[0.12] rounded-lg overflow-hidden"
  >
    <YourPopoutComponent
      :data="editingTask"
      class="h-full"
      @close="editingTask = null"
    />
  </div>

  <!-- Normal day columns -->
  <div v-for="(day, dayIndex) in weekDays" ...>
    ...
  </div>
</div>
```

### Step 2: Key CSS Classes

```css
absolute inset-0    /* Fills entire parent grid */
z-30                /* Above day columns (z-10) */
bg-card             /* Solid background to cover content */
border              /* Visual boundary */
rounded-lg          /* Match calendar styling */
overflow-hidden     /* Contain scrollable content */
h-full              /* Component fills overlay height */
```

### Step 3: Conditional Display Logic

For components that need to choose between inline popout and modal:

```typescript
const openEditTask = (task: Task, date: Date, dayIndex?: number) => {
  // Week view on desktop → inline popout
  if (calendarStore.viewMode === 'week' && !isMobile.value) {
    editingTask.value = task
    editingDayIndex.value = dayIndex ?? 0
    return
  }
  
  // Otherwise → modal
  showTaskFormModal.value = true
}
```

### Step 4: Component Requirements

The popout component should:
- Accept `class="h-full"` to fill container height
- Emit `@close` event to dismiss
- Use internal scrolling for long content
- Support `inline-mode` prop if used both inline and as modal

## Example: Trip Detail Modal

The `TripDetailModal` component supports both modes:

```vue
<!-- Inline mode in week view -->
<TripDetailModal
  :trip-id="selectedTripId"
  :inline-mode="true"
  class="h-full"
  @close="closeTripDetailModal"
/>

<!-- Modal mode for mobile/month view -->
<TripDetailModal
  v-if="showTripModal && !isWeekViewDesktop"
  :trip-id="selectedTripId"
  @close="showTripModal = false"
/>
```

## Mobile Fallback

Always check for mobile viewport before using inline popout:

```typescript
const isMobile = ref(false)
const checkMobile = () => {
  isMobile.value = window.innerWidth < 768 // md breakpoint
}

onMounted(() => {
  checkMobile()
  window.addEventListener('resize', checkMobile)
})
```

On mobile, use traditional modals with `Teleport` for better UX.

## Common Gotchas

1. **Z-index conflicts**: Ensure popout `z-30` is higher than day columns
2. **Height management**: Both overlay div AND component need proper height
3. **Close button**: Always provide clear dismiss action
4. **State cleanup**: Reset refs on close to prevent stale data
5. **View mode switching**: Clear popout state when switching between week/month views
