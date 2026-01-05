---
name: lifeOS UI Redesign
overview: Rebrand the app from MegaPlanner to lifeOS with a fresh green color theme, custom logo/favicon, and modernized UI components across all views while maintaining a clean, professional aesthetic.
todos:
  - id: branding
    content: Update app name to lifeOS across HTML, components, and meta tags
    status: completed
  - id: color-theme
    content: Implement green color theme in CSS custom properties (light + dark mode)
    status: completed
  - id: logo-favicon
    content: Create custom lifeOS SVG logo and favicon with leaf/grid motif
    status: completed
  - id: typography
    content: Switch to Sora font and refine typography settings
    status: completed
  - id: components
    content: Enhance Card, Button, and global styles for cleaner look
    status: completed
  - id: layout
    content: Polish Sidebar, TopNav, and AppShell layout components
    status: completed
  - id: views
    content: Refine all view pages (Login, Dashboard, Calendar, Budget, Inventory, Notes)
    status: completed
---

# lifeOS UI/UX Redesign

## 1. Branding and Color Theme

**Rename app from "MegaPlanner" to "lifeOS"** in:

- [client/index.html](client/index.html) - title, meta tags, theme-color
- [client/src/components/layout/Sidebar.vue](client/src/components/layout/Sidebar.vue) - logo text and version
- [client/src/views/auth/LoginView.vue](client/src/views/auth/LoginView.vue) - login branding

**Update color system** in [client/src/assets/index.css](client/src/assets/index.css):

- Primary: Deep forest green (HSL ~142 70% 45%)
- Accent: Warm sage/gold accent for highlights
- Light mode: Soft off-white backgrounds with green accents
- Dark mode: Deep charcoal with green accents

## 2. Custom Logo and Favicon

Create new SVG assets in `client/public/`:

- `favicon.svg` - Icon variant (leaf/grid motif representing life organization)
- Update `site.webmanifest` with new app name

Design concept: Geometric leaf shape integrated with grid lines to represent "life organization"

## 3. Typography and Spacing Refinements

Update [client/tailwind.config.js](client/tailwind.config.js):

- Change font from Outfit to **Sora** (more distinctive, modern sans-serif)
- Add custom letter-spacing for headings
- Fine-tune border-radius values

Update [client/index.html](client/index.html) with new Google Fonts import

## 4. Component Enhancements

**Cards** ([client/src/components/ui/card/Card.vue](client/src/components/ui/card/Card.vue)):

- Subtle hover state with soft shadow lift
- Refined border styling

**Buttons** ([client/src/components/ui/button/Button.vue](client/src/components/ui/button/Button.vue)):

- Slightly larger touch targets
- Better hover/active states

**Global CSS** ([client/src/assets/index.css](client/src/assets/index.css)):

- Refined scrollbar styling
- Better focus states
- Subtle selection color

## 5. Layout Polish

**Sidebar** ([client/src/components/layout/Sidebar.vue](client/src/components/layout/Sidebar.vue)):

- Redesigned logo area with icon + text
- Improved nav item styling with subtle indicator
- Footer refinement

**TopNav** ([client/src/components/layout/TopNav.vue](client/src/components/layout/TopNav.vue)):

- Cleaner search bar styling
- Improved user menu dropdown

**AppShell** ([client/src/components/layout/AppShell.vue](client/src/components/layout/AppShell.vue)):

- Subtle background pattern/gradient in main area

## 6. View-Specific Improvements

**Login** ([client/src/views/auth/LoginView.vue](client/src/views/auth/LoginView.vue)):

- Distinctive background pattern
- Logo with icon variant
- Refined card styling

**Dashboard** ([client/src/views/DashboardView.vue](client/src/views/DashboardView.vue)):

- Better stat card visual hierarchy
- Improved empty state illustrations
- Refined task/inventory list items

**Calendar** ([client/src/views/calendar/CalendarView.vue](client/src/views/calendar/CalendarView.vue)):

- Cleaner day cell styling
- Better today indicator
- Improved task card colors

**Budget** ([client/src/views/budget/BudgetView.vue](client/src/views/budget/BudgetView.vue)):

- Better summary cards visual differentiation
- Cleaner calendar grid

**Inventory** ([client/src/views/inventory/InventoryView.vue](client/src/views/inventory/InventoryView.vue)):

- Improved sheet card hover states
- Better empty state

**Notes** ([client/src/views/notes/NotebooksView.vue](client/src/views/notes/NotebooksView.vue)):

- Cleaner notebook card styling
- Better expansion animation

---

## Color Palette Preview

| Token | Light Mode | Dark Mode | Usage ||-------|------------|-----------|-------|| Primary | `142 70% 45%` | `142 70% 50%` | Main actions, links || Accent | `45 90% 55%` | `45 85% 50%` | Highlights, badges || Background | `120 10% 98%` | `160 20% 8%` | Page background || Card | `0 0% 100%` | `160 15% 12%` | Card surfaces || Muted | `120 10% 96%` | `160 15% 16%` | Subtle backgrounds |---

## Files to Modify

1. `client/index.html`
2. `client/src/assets/index.css`
3. `client/tailwind.config.js`
4. `client/public/favicon.svg`
5. `client/public/site.webmanifest`
6. `client/src/components/layout/Sidebar.vue`
7. `client/src/components/layout/TopNav.vue`
8. `client/src/components/layout/AppShell.vue`
9. `client/src/components/ui/card/Card.vue`
10. `client/src/components/ui/button/Button.vue`
11. `client/src/views/auth/LoginView.vue`
12. `client/src/views/DashboardView.vue`
13. `client/src/views/calendar/CalendarView.vue`