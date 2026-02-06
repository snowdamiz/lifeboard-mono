---
description: How to debug and verify Vue reactivity for user interactions
---

# Vue Reactivity Testing Skill

## Overview
When a user interaction (click, input, etc.) should trigger a GUI change, follow this debugging and verification workflow.

## The Reactivity Chain

```
User Action → Event Handler → State Change → Template Re-render → Visual Update
     ↓              ↓              ↓               ↓               ↓
  @click        function()     ref.value =     v-if/v-show      DOM update
```

## Step 1: Verify Event Handler Is Called

Add console.log at the start of your handler:

```typescript
const openNewTask = (date?: Date, dayIndex?: number) => {
  console.log('openNewTask called', { date, dayIndex })
  // ... rest of function
}
```

**Check browser console (F12)** - if no log appears, the event isn't firing.

## Step 2: Verify State Change

Log the state after setting it:

```typescript
showCreatePopout.value = true
console.log('State after setting:', { showCreatePopout: showCreatePopout.value })
```

## Step 3: Check Template v-if Conditions

If state is correct but UI doesn't update, the issue is in template reactivity.

### Common Reactivity Pitfalls

| Issue | Symptom | Fix |
|-------|---------|-----|
| **Object/Date in v-if** | State set but template doesn't update | Use explicit boolean flag |
| **Deep nested ref** | Child property change not detected | Use `shallowRef` or flatten structure |
| **Array mutation** | Push/splice not reactive | Use spread operator: `arr.value = [...arr.value, item]` |
| **Component reuse** | Props change but component doesn't reinitialize | Add `watch` on props or use `:key` |

### The Boolean Flag Pattern

**Problem:** `v-if="creatingTaskDate"` where `creatingTaskDate` is a `ref<Date | null>`

Vue may not reliably trigger re-renders when Date objects change.

**Solution:** Add explicit boolean:

```typescript
const creatingTaskDate = ref<Date | null>(null)
const showCreatePopout = ref(false) // Explicit flag

// In handler:
creatingTaskDate.value = targetDate
showCreatePopout.value = true // Reliable reactivity trigger

// In template:
v-if="showCreatePopout"  // Instead of v-if="creatingTaskDate"
```

## Step 4: Check CSS/Visibility Issues

If state AND template are correct but still not visible:

1. **z-index conflicts** - Element might be behind another
2. **Absolute positioning** - Parent without `position: relative`
3. **Overflow hidden** - Container clipping content
4. **Display/opacity** - Check computed styles

## Step 5: Component Prop Reactivity

When a component receives changing props but doesn't update:

```typescript
// Add watch on props to reinitialize
watch(() => [props.task, props.initialDate], () => {
  initForm()
}, { immediate: false })
```

## Debugging Checklist

```markdown
[ ] 1. Event handler fires (console.log at start)
[ ] 2. State value changes (console.log after assignment)
[ ] 3. v-if condition evaluates to true (use boolean flag)
[ ] 4. Element is visible in DOM (inspect element)
[ ] 5. No CSS issues hiding element (check z-index, position)
[ ] 6. Child components reinitialize on prop changes (add watch)
```

## Real Example: Task Create Popout

**User action:** Click "+" button to create task in week view

**Expected result:** Full-width inline form appears spanning all 7 columns

**Debugging session:**
1. ✅ `openNewTask called` appeared in console
2. ✅ `creatingTaskDate` was set correctly
3. ❌ Popout didn't appear - v-if using Date object wasn't reactive
4. ✅ Added `showCreatePopout` boolean flag - works!

## Key Principle

> **When in doubt, use a boolean flag.** Complex objects (Date, nested objects) as v-if conditions can have unpredictable reactivity. Always pair them with a simple boolean for template conditions.
