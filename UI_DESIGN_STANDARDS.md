# UI Design Standards

This document defines the visual design standards established during the Calendar redesign. Use these patterns to maintain consistency across all modules in the application.

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Component Patterns](#component-patterns)
5. [Layout & Spacing](#layout--spacing)
6. [Interactive States](#interactive-states)
7. [Depth & Effects](#depth--effects)
8. [Code Examples](#code-examples)

---

## Design Philosophy

### Core Principles

1. **Premium Aesthetic** - Interfaces should feel polished and modern, not utilitarian
2. **Visual Hierarchy** - Use color, size, and spacing to guide the eye naturally
3. **Subtle Depth** - Layering through gradients, shadows, and blur creates dimension
4. **Contextual Color** - Status and priority should be instantly recognizable through color
5. **Purposeful Animation** - Motion should feel responsive, not decorative

### Dark Theme Foundation

The application uses a dark theme with carefully controlled contrast levels:
- Avoid pure black (`#000`) - use `bg-card` or dark grays
- Avoid pure white (`#fff`) for text - use `text-foreground` with opacity
- Use semi-transparent whites (`white/[0.xx]`) for layering

---

## Color System

### Status Colors

| Status | Color Class | Tailwind Value | Usage |
|--------|-------------|----------------|-------|
| Completed | `bg-emerald-500` | `#10b981` | Completed tasks, success states |
| In Progress | `bg-amber-500` | `#f59e0b` | Active/ongoing items |
| High Priority | `bg-rose-500` | `#f43f5e` | Urgent items, priority 1 |
| Medium Priority | `bg-orange-400` | `#fb923c` | Important items, priority 2 |
| Default/Primary | `bg-primary` | Theme primary | Standard items, priority 3+ |

### Status Color Implementation

```typescript
// Example: Computing accent color based on status/priority
const accentColor = computed(() => {
  if (item.status === 'completed') return 'bg-emerald-500'
  if (item.status === 'in_progress') return 'bg-amber-500'
  if (item.priority === 1) return 'bg-rose-500'
  if (item.priority === 2) return 'bg-orange-400'
  return 'bg-primary'
})
```

### Surface Colors

| Element | Light Mode | Dark Mode | Usage |
|---------|------------|-----------|-------|
| Card Background | `bg-card` | `bg-card` | Primary content containers |
| Elevated Surface | `bg-white/[0.04]` | Subtle lift | Hovered or focused elements |
| Inset Surface | `bg-black/20` | Depressed areas | Inactive or muted sections |
| Border | `border-white/[0.06]` | Subtle separation | Grid lines, dividers |
| Border (hover) | `border-white/[0.12]` | Interactive feedback | Hovered elements |

### Transparency Scale

Use these opacity values consistently for white overlays on dark backgrounds:

| Opacity | Usage |
|---------|-------|
| `white/[0.01]` | Barely visible differentiation (weekend columns) |
| `white/[0.03]` | Subtle background (meta badges, grid gaps) |
| `white/[0.04]` | Light elevation (header backgrounds) |
| `white/[0.06]` | Borders, dividers |
| `white/[0.08]` | Pill backgrounds, hover states |
| `white/[0.10]` | Strong hover, active states |
| `white/[0.12]` | Interactive borders on hover |

---

## Typography

### Font Sizes

| Size | Class | Usage |
|------|-------|-------|
| 9px | `text-[9px]` | Micro badges, overflow counts |
| 10px | `text-[10px]` | Meta information, secondary badges |
| 11px | `text-[11px]` | Compact item titles, labels |
| 13px | `text-[13px]` | Standard card titles |
| sm (14px) | `text-sm` | Day numbers, expanded headers |

### Font Weights

| Weight | Class | Usage |
|--------|-------|-------|
| Normal | `font-normal` | Body text, descriptions |
| Medium | `font-medium` | Meta labels, secondary headings |
| Semibold | `font-semibold` | Day numbers, card titles, headers |

### Typography Patterns

**Header with tracking:**
```html
<span class="text-[11px] font-semibold uppercase tracking-widest text-muted-foreground">
  Monday
</span>
```

**Compact item title:**
```html
<span class="text-[11px] leading-tight truncate text-foreground/90">
  {{ item.title }}
</span>
```

**Meta badge:**
```html
<span class="text-[10px] font-medium px-1.5 py-0.5 rounded-full bg-white/[0.06]">
  {{ count }}
</span>
```

---

## Component Patterns

### Card Variants

#### 1. Compact Card (for dense lists)
Used in month calendar cells where space is limited.

```html
<div class="group relative flex items-center gap-1.5 px-1.5 py-1 rounded-md 
            cursor-pointer transition-all duration-150
            hover:bg-white/5 hover:shadow-sm">
  <!-- Accent dot -->
  <span :class="['w-1.5 h-1.5 rounded-full shrink-0', accentColor]" />
  
  <!-- Title -->
  <span class="text-[11px] leading-tight truncate flex-1 text-foreground/90">
    {{ title }}
  </span>
  
  <!-- Optional time -->
  <span class="text-[9px] text-muted-foreground/70 tabular-nums shrink-0">
    {{ time }}
  </span>
</div>
```

#### 2. Full Card (for detail views)
Used in week view, expanded dropdowns, and detail panels.

```html
<div class="group relative overflow-hidden rounded-lg transition-all duration-200 cursor-pointer
            border border-white/[0.06] hover:border-white/[0.12]
            bg-gradient-to-br hover:shadow-lg hover:shadow-black/10
            from-white/[0.04] to-transparent hover:from-white/[0.07]">
  <!-- Colored accent bar -->
  <div :class="['absolute left-0 top-0 bottom-0 w-[3px]', accentColor]" />
  
  <div class="pl-3 pr-2 py-2">
    <!-- Content -->
  </div>
</div>
```

### Badge Variants

#### Count Badge (pill style)
```html
<span class="inline-flex items-center gap-1 text-[10px] font-medium 
             px-1.5 py-0.5 rounded-full bg-white/[0.06] text-muted-foreground/70">
  {{ count }}
</span>
```

#### Active/Highlighted Badge
```html
<span class="inline-flex items-center gap-1 text-[10px] font-medium 
             px-1.5 py-0.5 rounded-full bg-primary/20 text-primary">
  {{ count }}
</span>
```

#### Meta Badge (inline)
```html
<span class="inline-flex items-center gap-1 text-[11px] text-muted-foreground/80 
             bg-white/[0.03] px-1.5 py-0.5 rounded">
  <Icon class="h-3 w-3" />
  {{ value }}
</span>
```

### Button Variants

#### Add Button (floating, hover-reveal)
```html
<button class="opacity-0 group-hover:opacity-100 
               absolute bottom-2 right-2 h-7 w-7 rounded-full 
               flex items-center justify-center transition-all duration-200 z-10
               bg-primary/20 hover:bg-primary/30 hover:scale-110
               shadow-lg shadow-primary/10">
  <Plus class="h-4 w-4 text-primary" />
</button>
```

#### Overflow Indicator Button
```html
<button class="flex items-center justify-center gap-1 w-full py-1 rounded-md 
               text-[10px] font-medium transition-all cursor-pointer
               bg-gradient-to-r from-white/[0.03] to-transparent
               hover:from-white/[0.08] hover:to-white/[0.02]
               text-muted-foreground/70 hover:text-primary">
  <span class="inline-flex items-center justify-center h-4 min-w-[16px] px-1 
               rounded-sm bg-white/[0.08] text-[9px]">
    +{{ count }}
  </span>
  <span>more</span>
</button>
```

### ClickableCard Pattern

When placing action buttons inside clickable cards, use one of these approaches to prevent event propagation issues:

#### Option 1: Use `ClickableCard` Component (Recommended)
```html
<ClickableCard @click="navigateToDetail(item.id)">
  <!-- Card content -->
  <template #actions>
    <EditButton @click="edit(item)" />
    <DeleteButton @click="delete(item.id)" />
  </template>
</ClickableCard>
```

#### Option 2: Wrapper with `@click.stop`
```html
<Card class="cursor-pointer" @click="navigate">
  <div class="flex items-center gap-3">
    <div class="flex-1">Content</div>
    <div class="flex gap-1" @click.stop>
      <EditButton @click="edit" />
      <DeleteButton @click="delete" />
    </div>
  </div>
</Card>
```

#### Option 3: Individual `.stop` modifiers
```html
<EditButton @click.stop="edit" />
<DeleteButton @click.stop="delete" />
```

> ⚠️ **Never** place buttons inside a clickable parent without stopping propagation. This causes clicks on buttons to also trigger the parent's click handler.

---

## Layout & Spacing

### Grid Cells

```html
<div class="group relative flex flex-col min-h-[110px] transition-all duration-200
            border-r border-b border-white/[0.04]
            hover:bg-white/[0.03] hover:z-[1]">
  <!-- Header -->
  <div class="px-2 py-1.5 flex items-center justify-between border-b border-transparent">
    <!-- Content -->
  </div>
  
  <!-- Body -->
  <div class="flex-1 px-1.5 py-1 space-y-0.5 overflow-hidden relative">
    <!-- Items -->
  </div>
</div>
```

### Cell States

| State | Classes |
|-------|---------|
| Default | `bg-card` |
| Today | `bg-primary/[0.06] ring-1 ring-inset ring-primary/20` |
| Inactive/Outside | `bg-black/20` |
| Weekend | `bg-white/[0.01]` |
| Hover | `hover:bg-white/[0.03] hover:z-[1]` |

### Empty State

```html
<div class="absolute inset-0 flex items-center justify-center 
            opacity-0 group-hover:opacity-100 transition-opacity">
  <div class="w-8 h-8 rounded-full bg-white/[0.03] 
              flex items-center justify-center 
              border border-dashed border-white/[0.08]">
    <Plus class="h-4 w-4 text-muted-foreground/40" />
  </div>
</div>
```

---

## Interactive States

### Hover Transitions

All interactive elements should use smooth transitions:

```css
transition-all duration-150  /* Fast, for small elements */
transition-all duration-200  /* Standard, for cards */
transition-opacity duration-150  /* For reveal animations */
```

### Hover Reveal Pattern

Elements that appear on hover (actions, buttons):

```html
<div class="opacity-0 group-hover:opacity-100 transition-opacity duration-150">
  <!-- Hidden content -->
</div>
```

### Scale on Hover

For primary actions:
```html
<button class="hover:scale-110 transition-all duration-200">
```

---

## Depth & Effects

### Glassmorphism Modal

For expanded dropdowns and floating panels:

```html
<div class="backdrop-blur-xl bg-card/95 
            border border-white/[0.1] 
            shadow-2xl shadow-black/40 
            rounded-lg">
  <!-- Content -->
</div>
```

### Backdrop Overlay

```html
<div class="fixed inset-0 z-10 bg-black/20 backdrop-blur-sm cursor-default" 
     @click="close" />
```

### Shadow Hierarchy

| Level | Classes | Usage |
|-------|---------|-------|
| Subtle | `shadow-sm` | Hovered cards |
| Standard | `shadow-lg shadow-black/5` | Containers |
| Elevated | `shadow-lg shadow-black/10` | Hovered cards |
| Modal | `shadow-2xl shadow-black/40` | Dropdowns, modals |
| Glow | `shadow-lg shadow-primary/10` | Primary action buttons |
| Today | `shadow-lg shadow-primary/30` | Today indicator |

### Gradient Backgrounds

**Container gradient:**
```html
<div class="bg-gradient-to-br from-card to-card/95">
```

**Header gradient:**
```html
<div class="bg-gradient-to-b from-white/[0.04] to-transparent">
```

**Card gradient (dark mode):**
```html
<div class="bg-gradient-to-br from-white/[0.04] to-transparent hover:from-white/[0.07]">
```

---

## Code Examples

### Status Icon Pattern

Dynamic icon based on status:

```typescript
import { CheckCircle2, Circle, PlayCircle } from 'lucide-vue-next'

const statusIcon = computed(() => {
  if (item.status === 'completed') return CheckCircle2
  if (item.status === 'in_progress') return PlayCircle
  return Circle
})
```

```html
<component 
  :is="statusIcon" 
  :class="[
    'h-4 w-4 transition-all duration-150',
    item.status === 'completed' 
      ? 'text-emerald-500' 
      : item.status === 'in_progress'
        ? 'text-amber-500'
        : 'text-muted-foreground/50 hover:text-primary'
  ]"
/>
```

### Weekend Detection

```typescript
// dayIndex is the position in the week (0-6)
// Days 5 and 6 are Saturday and Sunday in a Monday-first week
const isWeekend = dayIndex % 7 >= 5
```

### Conditional Cell Styling

```html
<div
  :class="[
    'group relative flex flex-col min-h-[110px] transition-all duration-200',
    'border-r border-b border-white/[0.04]',
    isToday(day) 
      ? 'bg-primary/[0.06] ring-1 ring-inset ring-primary/20' 
      : !isSameMonth(day, currentDate)
        ? 'bg-black/20'
        : dayIndex % 7 >= 5 
          ? 'bg-white/[0.01]' 
          : 'bg-card',
    'hover:bg-white/[0.03] hover:z-[1]'
  ]"
>
```

---

## Checklist for New Components

When creating new UI components, verify:

- [ ] Uses status colors consistently (emerald/amber/rose/orange/primary)
- [ ] Has appropriate hover states with transitions
- [ ] Uses semi-transparent whites for layering (not solid colors)
- [ ] Typography follows the established scale (9/10/11/13px)
- [ ] Interactive elements have `group-hover:opacity-100` reveal pattern
- [ ] Cards have gradient backgrounds and accent bars where appropriate
- [ ] Modals/dropdowns use glassmorphism effect
- [ ] Shadows use the defined hierarchy
- [ ] Animations use 150ms (fast) or 200ms (standard) duration
- [ ] Badges use rounded-full for counts, rounded for meta info
- [ ] **Buttons inside clickable cards use `.stop` or `ClickableCard` component**

---

## Files Modified

These files contain the reference implementation:

- `client/src/components/calendar/TaskCard.vue` - Card variants, status colors
- `client/src/views/calendar/CalendarView.vue` - Grid cells, layout patterns

---

*Last updated: 2026-01-31*
