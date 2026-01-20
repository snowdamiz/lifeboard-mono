# LifeBoard Bugs & Feature Requests

> **Created**: 2026-01-12  
> **Status**: Planning

---

## 🛒 Shopping List

| Type | Description |
|------|-------------|
| 🐛 Bug | Can't add item to shopping list |
| 🐛 Bug | Auto-generated shopping list doesn't have delete option |
| ✨ Feature | Shopping lists should be editable |

---

## 📝 Notes

### Interaction Improvements
- [ ] Replace vertical dots menu with **double-click to rename** for notebooks and pages
- [ ] Reveal delete button for notebooks
- [ ] Add delete button for pages

### Text Editor
- [ ] Main text box should grow **unlimitedly** with each line break (dynamic height)

### Grid Input
- [ ] Add **cell grid input option** with user-defined X by Y dimensions
- [ ] Allow users to modify grid size after creation

---

## 💰 Budget Source

### Recurring Options
- [ ] Expand recurring checkbox with additional options:
  - Every second Tuesday
  - Other bi-weekly/custom recurrence patterns

### Calendar Views
- [ ] Add **weekly view** alongside monthly view
- [ ] Style weekly view with same functionality as Calendar views

### Budget Calendar Bugs
| Type | Description |
|------|-------------|
| 🐛 Bug | Sources generated in the budget calendar do not get saved |
| 🐛 Bug | Sources in budget calendar do not show source name and can't be edited |
| ✨ Feature | Instead of space for 2 sources in month view, show **net diff** only |
| 🐛 Bug | Trip purchases not appearing on correct date in Budget Calendar [FIXED] |

### Savings Rate
- [ ] Add **"Reset to X day"** option for savings rate
- [ ] Add **"Rolling X days"** option for savings rate

---

## ⚙️ Settings & UI

### Layout Changes
- [ ] Move the **Button/Icon toggle button** (next to LifeBoard logo) into Settings

### Confirmation Dialogs
- [ ] Remove all confirmation pop-ups **except** for "Delete all data" button

### Calendar Navigation
- [ ] Make it more obvious that Week/Month radio buttons are tied to left/right arrows
- [ ] Move "Today" button to the **left of "Week"**

---

## 📦 Inventory

- [ ] Convert inventory sheets into **lines like Habits** (consistent list format)

---

## 🎯 Dashboard & Task Management

### Task Bugs
| Type | Description |
|------|-------------|
| 🐛 Bug | Can't add additional task after initial creation |
| 🐛 Bug | Editing Dashboard and pressing cancel **applies changes anyway** |
| 🐛 Bug | Clicking on a Task in Dashboard doesn't navigate to task (should behave like Active Goals widget) |
| 🐛 Bug | Clicking on a Habit in Habits doesn't navigate to habit details |

---

## 📋 Standardized List Item GUI

> **Applies to**: Goals, Habits, Shopping List, Notes, and all dashboards with list views

### List Item (Not Clicked)
- [ ] Show **edit** and **delete** buttons directly on each item
- [ ] Standardize appearance across all list types

### List Item (Clicked/Expanded)
- [ ] Clicking should **expand inline** to show details (dropdown style)
- [ ] **No navigation to a new page** — keep user in context
- [ ] Apply consistently to: Goals, Habits, Shopping List items, Notes, etc.

### Bulk Operations
- [ ] Add **bulk selection** capability (select multiple items)
- [ ] Bulk **delete** for selected items
- [ ] **Multi-sort filtering**: combine multiple sorts (e.g., time ascending AND name descending)

### Advanced Filtering
- [ ] Filter by **dropdown of unique names** with checkboxes
- [ ] Add **regex filtering option**

---

## 📅 Calendar Task Display

### Task Actions
- [ ] Replace triple-dot menu on tasks with **inline edit/delete buttons**
- [ ] Edit button on top, delete button below (or beside)

### Day Cell Popup (Month View)
- [ ] Clicking on day number **enlarges the cell** as a popup
- [ ] Blur background of rest of calendar
- [ ] Show **grid of all tasks** for that day with:
  - Full task names
  - First line of description
  - Edit and delete buttons

---

## Summary by Priority

### 🔴 Critical Bugs
1. Can't add item to shopping list
2. Editing Dashboard cancel button applies changes
3. Can't add additional task after initial creation
4. Budget sources don't save / can't be edited

### 🟡 UX Improvements
1. Standardize list item GUI across all dashboards
2. Inline expand for list items (no page navigation)
3. Calendar task popup for month view
4. Remove confirmation pop-ups (except delete all)

### 🟢 New Features
1. Grid input for Notes
2. Weekly view for Budget
3. Advanced recurring options (every second Tuesday, etc.)
4. Bulk operations and regex filtering
5. Savings rate reset/rolling options
