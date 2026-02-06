---
description: How to check for and prevent Global Click Collision Hazard in Vue components with outside-click handlers
---

# Global Click Collision Hazard Skill

This skill describes how to identify and prevent the **Global Click Collision Hazard** - a bug where clicking a trigger button immediately closes the UI it was supposed to open.

## The Problem

When a Vue component has an "outside click" handler (using `document.addEventListener('click')`), the click event that triggers the component can bubble up to the document and immediately close it.

### Symptoms
- Button click "does nothing" visually
- Console logs show component opening then immediately closing
- UI flickers briefly

### Root Cause
1. User clicks trigger button
2. Button's `@click` handler mounts the component
3. Component's `onMounted` attaches document click listener
4. **Same click event** bubbles to document
5. Handler sees click was "outside" (on the button, not inside the new component)
6. Component emits `close` immediately

## Detection Checklist

When adding or debugging trigger buttons for popouts/modals:

### 1. Check for Outside Click Handler
Look for this pattern in the target component:

```typescript
// Component being triggered
onMounted(() => {
  document.addEventListener('click', handleOutsideClick)
})

const handleOutsideClick = (e: MouseEvent) => {
  if (popoutRef.value && !popoutRef.value.contains(e.target as Node)) {
    emit('close')
  }
}
```

### 2. Verify Trigger Has `.stop` Modifier
**Every button that opens such a component MUST have `.stop`:**

```vue
<!-- ✅ CORRECT -->
<Button @click.stop="openPopout()">Open</Button>

<!-- ❌ WRONG - Will cause immediate closure -->
<Button @click="openPopout()">Open</Button>
```

### 3. Search Pattern
Run this command to find potential issues:

```bash
# Find all outside click handlers
grep -rn "document.addEventListener.*click" client/src/components/

# Then for each component found, search for its trigger buttons
grep -rn "ComponentName" client/src/views/ | grep "@click"
```

## Prevention Rules

1. **Always use `.stop`** on buttons that trigger popouts with outside-click handlers
2. **Add `@click.stop`** on the popout's root element to prevent interior clicks from bubbling
3. **Document the requirement** in component's JSDoc or comment

## Components with Outside Click Handlers

These components use document click listeners and require `.stop` on triggers:

| Component | File | Triggers Need `.stop` |
|-----------|------|----------------------|
| `TaskDetailPopout` | `components/calendar/TaskDetailPopout.vue` | ✅ Yes |
| Filter dropdowns | Various | ✅ Yes |

## Testing

Add a Playwright test that verifies the popout stays open after clicking the trigger:

```typescript
test('Create button opens inline editor (no immediate close)', async ({ page }) => {
  await page.goto('/calendar')
  
  const addButton = page.locator('[data-testid="add-button"]').first()
  await addButton.click()
  
  // Wait for potential close (the bug would close it within 100ms)
  await page.waitForTimeout(200)
  
  // Verify popout is still visible
  const popout = page.locator('[data-testid="task-detail-popout"]')
  await expect(popout).toBeVisible()
})
```

## Related Knowledge

- See [IGWO Implementation Skill](../knowledge/calendar_and_planning_system/artifacts/implementation/inline_grid_workspace_overlay_skill.md) Section 11.6
- See [Vue Reactivity Testing Workflow](./vue-reactivity-testing.md)
