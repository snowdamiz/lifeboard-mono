---
name: Bug Noting
description: Standardized way to document bugs in Lifeboard. Converts casual user descriptions into structured, actionable bug reports with screenshots, affected components, and fix references. Use this skill whenever a bug is reported to create a consistent, unambiguous record.
---

# Bug Noting Skill

This skill defines the standard format and workflow for documenting bugs in Lifeboard. It translates raw user observations (often with screenshots and informal descriptions) into structured, developer-ready bug reports.

## When to Use

- A user reports unexpected behavior in prod or dev
- You observe a regression or inconsistency during development
- You need to create a traceable record of a known issue

## Bug Report Format

Every bug is filed in `.agent/bugs/BUG-XXXX.md` where `XXXX` is a zero-padded sequential ID.

### Template

```markdown
---
id: BUG-XXXX
title: <Short, specific title>
severity: critical | high | medium | low
status: open | in-progress | fixed | wont-fix
reported: YYYY-MM-DD
fixed: null
affected_views:
  - <ViewName or ComponentName>
---

# BUG-XXXX: <Title>

## Summary
<1-2 sentence description of what's wrong, written so anyone can understand it without screenshots>

## Steps to Reproduce
1. <Step 1>
2. <Step 2>
3. ...

## Expected Behavior
<What should happen>

## Actual Behavior
<What actually happens — reference screenshots by label like SC1, SC2, etc.>

## Screenshots
| Label | Description |
|-------|-------------|
| SC1   | <what this screenshot shows> |
| SC2   | <what this screenshot shows> |

## Affected Components
| Component | File Path | Role |
|-----------|-----------|------|
| <Name>    | `client/src/components/...` | <what it does in context> |

## Root Cause Analysis
<If known: what's causing the discrepancy. If unknown: "TBD — needs investigation">

## Fix Strategy
<Outline the approach. Reference specific components, props, or patterns.>

### Relevant Skills & Workflows
- **Skill**: `<skill-name>` — <why it's relevant>
- **Workflow**: `/<workflow-name>` — <why it's relevant>

### Common Problems to Check
<Reference the common-problems skill for known gotchas. Example:>
- See `.agent/skills/common-problems/SKILL.md` for known patterns like:
  - Prop mapping mismatches in BaseItemEntry
  - Overflow/scroll issues in Teleport modals
  - Vue reactivity failures on Set/Map mutations

## Linked Bugs
- Depends on: <BUG-YYYY> (if any)
- Related: <BUG-YYYY> (if any)
```

## How to Create a Bug

### Step 1: Assign the next bug ID

Check the `.agent/bugs/` directory for the highest existing `BUG-XXXX.md` and increment by 1.

```powershell
# List existing bugs
Get-ChildItem c:\Users\yurlo\.gemini\antigravity\scratch\lifeboard-mono\.agent\bugs\*.md | Sort-Object Name
```

If no bugs exist yet, start with `BUG-0001`.

### Step 2: Parse the user's description

Users will report bugs casually. Your job is to:

1. **Identify the distinct issues** — one bug per file. If the user describes multiple problems, create separate bugs.
2. **Map screenshots to labels** — SC1, SC2, etc. Describe what each shows.
3. **Identify affected views** — which screens/components are involved.
4. **Trace to source components** — find the exact `.vue` or `.ex` files.

### Step 3: Fill in the template

- **Summary**: Write it as if the person reading has never seen the app. No ambiguity.
- **Steps to Reproduce**: Be specific. Include navigation paths like "Calendar > Week View > Click Trip Card > Manage Trip".
- **Affected Components**: Use `grep_search` or `find_by_name` to trace the render chain.
- **Fix Strategy**: Reference the component architecture. If `BaseItemEntry` is involved, note which props need alignment. If it's a CSS/layout issue, note the container and overflow properties.

### Step 4: Cross-reference skills and workflows

Always check these when filing a bug:

| Scenario | Skill/Workflow to Reference |
|----------|---------------------------|
| Item display inconsistency | KI: `GUI Design System`, Component: `BaseItemEntry.vue` |
| Calendar rendering issue | Workflow: `/calendar-popout`, KI: `Calendar and Planning System` |
| Click handler collisions | Workflow: `/click-collision-hazard` |
| Vue reactivity not updating | Workflow: `/vue-reactivity-testing` |
| Receipt parsing wrong | Workflow: `/receipt-parsing` |
| Overflow / scroll issues | Skill: `common-problems` (CSS overflow patterns) |
| Data not showing after action | KI: `Development Workflow and Troubleshooting` |
| Budget entry mismatch | KI: `Financial Logistics and Budget Management` |
| Inventory transfer issues | KI: `Inventory Management System` |

### Step 5: Reference common problems

Before writing Fix Strategy, always check `.agent/skills/common-problems/SKILL.md` for known patterns that might apply. Add any new patterns discovered during investigation.

## Severity Guide

| Severity | Definition | Example |
|----------|-----------|---------|
| **critical** | Data loss, crash, or completely blocks a workflow | Purchase deletion doesn't cascade to budget |
| **high** | Feature works but displays wrong data or is misleading | Item shows "40 lb" in one view, "20 lb" in another |
| **medium** | UI/UX annoyance that doesn't block functionality | List not scrollable but data is accessible another way |
| **low** | Cosmetic issue, minor inconsistency | Slightly different spacing between views |

## Maintaining the Bug Index

After creating a bug, update `.agent/bugs/INDEX.md` with a one-line summary:

```markdown
| BUG-XXXX | <title> | <severity> | <status> | <date> |
```
