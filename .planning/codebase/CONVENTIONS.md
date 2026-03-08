# Coding Conventions

**Analysis Date:** 2026-03-07

## Naming Patterns

**Files:**
- Vue components: PascalCase (e.g., `Card.vue`, `CardContent.vue`)
- TypeScript/JavaScript files: camelCase (e.g., `useTextTemplate.ts`, `formatCountUnit.ts`)
- Composables: `use*` prefix in camelCase (e.g., `useModal.ts`, `useAuthStore.ts`, `useListSorting.ts`)
- Stores: `use*Store` suffix (e.g., `useInventoryStore`, `useAuthStore`, `useBudgetStore`)
- Utilities: descriptive camelCase (e.g., `prefetch.ts`, `formatCountUnit.ts`, `units.ts`)
- Directories: kebab-case for feature groupings (e.g., `components/budget/`, `components/shared/`)

**Functions:**
- camelCase for all functions (e.g., `formatCountUnit`, `isOnLoginPage`, `navigateWithAuth`)
- Composable functions start with `use`: `useModal()`, `useAuthStore()`, `useCRUDStore()`
- Descriptive names indicating purpose: `navigateWithAuth`, `expectPageHeaderOrLogin`
- Async functions explicitly return Promises: `async function fetchSheets(): Promise<void>`

**Variables:**
- camelCase for all variables and constants: `loading`, `isOpen`, `accessToken`, `sheetFilterTags`
- Ref variables: camelCase with no special prefix (e.g., `const user = ref<User | null>(null)`)
- Computed properties: camelCase (e.g., `hasTokens`, `isAuthenticated`, `tripsByDate`)
- Boolean variables typically prefix with `is`, `has`, `can`: `isOpen`, `hasTokens`, `isAuthenticated`
- Private variables: use underscore prefix when needed in module scope

**Types:**
- Interface/Type names: PascalCase (e.g., `User`, `Task`, `InventorySheet`, `ModalConfig`)
- Union types use camelCase union member names: `task_type: 'todo' | 'timed' | 'floating' | 'trip'`
- Generic type parameters: Single uppercase letter (T, U, R) or descriptive PascalCase
- Exported types in centralized `src/types/index.ts`

## Code Style

**Formatting:**
- No auto-formatting tool configured (ESLint exists but no .eslintrc file found)
- Consistent indentation: 2 spaces throughout codebase
- Line continuations and statement wrapping observed in component templates
- Multi-line imports grouped by source: Vue imports, then type imports, then local imports

**Linting:**
- ESLint configured in `package.json` with `--fix` flag
- Vue plugin: `@vue/eslint-config-typescript`, `eslint-plugin-vue`
- Automatic fix on `npm run lint`: `eslint . --ext .vue,.js,.jsx,.cjs,.mjs,.ts,.tsx,.cts,.mts --fix`
- No explicit config file (.eslintrc) - relies on defaults with Vue 3 + TypeScript

**TypeScript:**
- Strict mode is standard: `noEmit: true` in tsconfig
- File extensions: `.ts` for pure TypeScript, `.vue` for components
- Type imports: `import type { User } from '@/types'` - explicit `type` keyword used

## Import Organization

**Order:**
1. External framework imports (Vue, Pinia): `import { ref, computed } from 'vue'`
2. External library imports: `import { defineStore } from 'pinia'`
3. Type-only imports: `import type { User } from '@/types'`
4. Internal absolute imports with @ alias: `import { api } from '@/services/api'`
5. Internal relative imports: rare, typically avoided via @ alias

**Path Aliases:**
- Single alias used: `@` maps to `./src/` (configured in `vite.config.ts`)
- All imports use absolute paths with `@/` prefix for consistency
- Examples: `@/services/api`, `@/stores/inventory`, `@/components/ui/card`, `@/lib/utils`

**Import Patterns:**
- Vue 3 Composition API: Named imports with types: `import { ref, computed, onMounted, type Ref, type ComputedRef }`
- Pinia stores: Import with `defineStore`: `import { defineStore } from 'pinia'`
- Custom utilities: Named function exports: `export function formatCountUnit(...)`
- Type collections in `src/types/index.ts`: Centralized, imported as needed

## Error Handling

**Patterns:**
- Try-catch with console.error logging for failed operations
- Error recovery: Return sensible defaults on failure
  - Empty array on fetch failure: `return []`
  - False boolean on operation failure: `return false`
  - Null or empty state for missing data
- Fire-and-forget async operations wrapped in `.catch()` for side effects (e.g., template saving)
- Explicit error type checking: `e instanceof Error ? e.message : 'Failed to X'`
- Generic error handling in composables: Log and return defaults rather than throwing
- Store error state: `error: Ref<string | null>` tracks last error, checked before operations

**Error Messages:**
- Contextual messages: `'Failed to search templates for ${type}'` with operation context
- Graceful degradation: Components skip functionality rather than crashing (e.g., `test.skip()` in tests for unauth)

## Logging

**Framework:** console object (no structured logging library)

**Patterns:**
- `console.error()` for errors: `console.error(\`Failed to search templates for ${type}\`, e)`
- `console.log()` for debug output: `console.log('[DEBUG] tripsByDate computing with trips:', trips.value.length)`
- Debug prefix `[DEBUG]` used for verbose logging (e.g., store computation output)
- Test logs: `console.log()` for test diagnostics like `'Route requires auth - on login page'`
- Conditional logging in tests: errors logged but operations continue (graceful handling)

## Comments

**When to Comment:**
- Complex algorithm explanation (e.g., `formatCountUnit` function has detailed logic comments)
- Important context for maintainers: Authentication flow explanation in `useAuthStore`
- Fire-and-forget patterns explicitly marked: `// Fire and forget` before async operations
- Legacy behavior documented: Old token migration documented inline

**JSDoc/TSDoc:**
- JSDoc blocks used for composite functions and composables
- Example `useModal`:
  ```typescript
  /**
   * Composable for modal state management and behavior.
   *
   * Consolidates patterns from FormModal and ConfirmDialog:
   * - Open/close state management
   * - Escape key handling
   * - Backdrop click handling
   * - Body scroll locking
   *
   * @example
   * ```vue
   * // Usage example
   * ```
   */
  ```
- Parameter descriptions in composable options interfaces
- Return type always explicit in interface definitions

## Function Design

**Size:** Functions typically 20-50 lines, complex utilities up to 80-100 lines

**Parameters:**
- Use interface/type parameters for complex options: `UseModalOptions`, `UseCRUDStoreOptions<T>`
- Destructure with defaults using `const { x = default } = options`
- Single parameter for data objects: `function updateTask(data: Partial<Task>)`
- Multiple small params acceptable if <= 3: `formatCountUnit(count, countUnit, units, unitMeasurement)`

**Return Values:**
- Async functions return Promise<T> explicitly typed
- Composables return objects with properties: `{ items, loading, error, fetch, create, update }`
- Helper functions return appropriate types: `Promise<boolean>`, `T | undefined`, `string`

## Module Design

**Exports:**
- Named exports standard: `export function formatCountUnit(...)`, `export const useModal = (...)`
- Store exports: `export const useAuthStore = defineStore('auth', () => {...})`
- Types exported from centralized `src/types/index.ts`
- Composables return configuration objects or state objects

**Barrel Files:**
- Not heavily used
- `src/types/index.ts` is a barrel collecting all type definitions
- Components import directly from specific files: `import Card from '@/components/ui/card/Card.vue'`

## Store Pattern (Pinia)

**Structure:**
- Use `defineStore('name', () => {...})` setup function syntax
- State: ref variables at top: `const user = ref<User | null>(null)`
- Computed: explicit `computed()` calls: `const isAuthenticated = computed(() => !!accessToken.value)`
- Methods: regular functions defined in function body
- Return object at end with all public API: `return { user, accessToken, isAuthenticated, checkAuth, logout }`

**Example (`useAuthStore`):**
```typescript
export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const accessToken = ref<string | null>(localStorage.getItem('access_token'))

  const isAuthenticated = computed(() => !!accessToken.value && !!user.value)

  async function checkAuth() { /* ... */ }
  function logout() { /* ... */ }

  return { user, accessToken, isAuthenticated, checkAuth, logout }
})
```

---

*Convention analysis: 2026-03-07*
